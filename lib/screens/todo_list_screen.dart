import 'package:flutter/material.dart';
import 'package:zen_assist/managers/family_invites.dart';
import 'package:zen_assist/managers/family_management.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';
import 'package:zen_assist/widgets/task_card.dart';
import 'package:zen_assist/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';

//Family Shared Account functions seem to work for now, members can be invited and removed, and they can see their family tasks
//Family Shared Account creators should be able to create more specific family tasks, where only certain family members can complete them

class ToDoListScreen extends StatefulWidget {
  const ToDoListScreen({super.key});

  @override
  _ToDoListScreenState createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _personalTasksStream;
  Stream<QuerySnapshot>? _familyTasksStream;
  String? familyId;
  bool isCreator = false;
  bool _isLoading = true;
  final String _selectedPriority = 'low';

  @override
  void initState() {
    super.initState();
    _loadUserFamilyData();
  }

  Future<void> _loadUserFamilyData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userData =
            await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists) {
          setState(() {
            familyId = userData.data()?['familyId'];
            isCreator = userData.data()?['role'] == 'creator';
          });
        }
        _setupStreams();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupStreams() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Personal tasks stream - always set up
    _personalTasksStream = _firestore
        .collection('todoList')
        .where('userId', isEqualTo: user.uid)
        .where('taskType', isEqualTo: 'personal')
        .orderBy('dueDate')
        .snapshots();

    // Family tasks stream - only if user has a family
    if (familyId != null) {
      _familyTasksStream = _firestore
          .collection('todoList')
          .where('familyId', isEqualTo: familyId)
          .where('taskType', isEqualTo: 'family')
          .orderBy('dueDate')
          .snapshots();
    }
  }

  Task _convertDocumentToTask(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    return Task(
      id: document.id,
      title: data['title'],
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] ?? false,
      userId: data['userId'],
      familyId: data['familyId'],
      taskType: data['taskType'],
      priority: data['priority'] ?? 'low',
    );
  }

  Future<void> _addTask(
    String title,
    DateTime dueDate,
    String taskType,
    String priority,
    String? assignedTo,
    String? description,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Check if the task is a family task
        if (taskType == 'family') {
          // Only allow creators to create family tasks
          if (!isCreator) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Only family creators can create family tasks')),
            );
            return;
          }

          // If it's a family task, ensure the familyId is not null
          if (familyId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'You must be part of a family to create family tasks')),
            );
            return;
          }

          // If assignedTo is null, create one task for the family with no specific assignment
          if (assignedTo == null) {
            await _firestore.collection('todoList').add({
              'title': title,
              'dueDate': Timestamp.fromDate(dueDate),
              'isCompleted': false,
              'userId': user.uid, // Keep creator as userId
              'createdAt': FieldValue.serverTimestamp(),
              'familyId': familyId, // Ensure familyId is set
              'taskType': 'family',
              'priority': priority,
              'assignedTo': null, // No member assigned
              'description': description ?? '',
            });
          } else {
            // If assignedTo is provided, create a task for a specific family member
            await _firestore.collection('todoList').add({
              'title': title,
              'dueDate': Timestamp.fromDate(dueDate),
              'isCompleted': false,
              'userId': assignedTo, // Assign task to the selected member
              'createdAt': FieldValue.serverTimestamp(),
              'familyId': familyId, // Ensure familyId is set
              'taskType': 'family',
              'priority': priority,
              'assignedTo': assignedTo, // Assign task to the selected member
              'description': description ?? '',
            });
          }
        } else {
          // If it's a personal task, create as usual for the creator (no familyId)
          await _firestore.collection('todoList').add({
            'title': title,
            'dueDate': Timestamp.fromDate(dueDate),
            'isCompleted': false,
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'taskType': 'personal',
            'priority': priority,
            'assignedTo': null, // Personal tasks don't have assigned members
            'description': description ?? '',
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding task: $e')),
      );
    }
  }

  void _showAddTaskDialog() {
    String newTaskTitle = '';
    DateTime selectedDate = DateTime.now();
    String taskType = 'personal'; // Default task type
    String priority = _selectedPriority;
    String? assignedTo; // Store the selected family member's ID
    String? description;

    List<String> taskTypes = ['personal', 'family'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: StatefulBuilder(
            // StatefulBuilder to dynamically rebuild UI
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      newTaskTitle = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                    ),
                  ),
                  TextField(
                    onChanged: (value) {
                      description = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: taskType,
                    items: taskTypes.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child:
                            Text(value[0].toUpperCase() + value.substring(1)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        taskType = newValue!; // Update the taskType
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Task Type'),
                  ),
                  const SizedBox(height: 16),

                  // Show family member dropdown if user is creator and task type is 'family'
                  if (isCreator && taskType == 'family' && familyId != null)
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore
                          .collection('users')
                          .where('familyId', isEqualTo: familyId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        // Filter out the creator from the family member list
                        final familyMembers = snapshot.data!.docs
                            .where((doc) =>
                                doc['role'] != 'creator') // Exclude creator
                            .map((doc) => {
                                  'id': doc.id,
                                  'email': doc['email'],
                                })
                            .toList();

                        return DropdownButtonFormField<String>(
                          value: assignedTo,
                          decoration: const InputDecoration(
                            labelText: 'Assign Task To',
                          ),
                          items: familyMembers.map((member) {
                            return DropdownMenuItem<String>(
                              value: member['id'],
                              child: Text(member['email']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              assignedTo = value; // Set assigned member's ID
                            });
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                    ),
                    items: TaskPriorityColors.priorityColors.keys
                        .map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: TaskPriorityColors.getColor(key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(key.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        priority = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2025),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                      }
                    },
                    child: const Text('Select Due Date'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newTaskTitle.isNotEmpty) {
                  _addTask(newTaskTitle, selectedDate, taskType, priority,
                      assignedTo, description);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTaskStatus(String taskId, bool isCompleted) async {
    try {
      await _firestore.collection('todoList').doc(taskId).update({
        'isCompleted': isCompleted,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: $e')),
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _firestore.collection('todoList').doc(taskId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting task: $e')),
      );
    }
  }

  Widget _buildTaskList(List<Task> tasks, bool isCompleted, String title) {
    final filteredTasks =
        tasks.where((task) => task.isCompleted == isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.green : Colors.blue,
            ),
          ),
        ),
        if (filteredTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              isCompleted ? 'No completed tasks' : 'No pending tasks',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            return Dismissible(
              key: Key(task.id!),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                _deleteTask(task.id!);
              },
              child: TaskCard(
                task: task,
                onComplete: () =>
                    _updateTaskStatus(task.id!, !task.isCompleted),
                additionalInfo: task.taskType == 'family'
                    ? 'Assigned to: ${task.assignedTo != null ? task.assignedTo : "Unassigned"}'
                    : 'Personal Task',
                priorityColor: TaskPriorityColors.getColor(task.priority),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFamilyManagementButton() {
    if (!isCreator || familyId == null) return const SizedBox.shrink();

    return FloatingActionButton(
      heroTag: 'familyManagement',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyManagement(
              familyId: familyId!,
              isCreator: isCreator,
            ),
          ),
        );
      },
      child: const Icon(Icons.family_restroom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-do List'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Family Invites widget - show only if user is part of a family
                  if (familyId != null) FamilyInvites(),

                  // Personal Tasks Section
                  StreamBuilder<QuerySnapshot>(
                    stream: _personalTasksStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final tasks = snapshot.data!.docs
                          .map((doc) => _convertDocumentToTask(doc))
                          .toList();
                      return Column(
                        children: [
                          _buildTaskList(
                              tasks, false, 'Personal Pending Tasks'),
                          _buildTaskList(
                              tasks, true, 'Personal Completed Tasks'),
                          if (familyId != null) const Divider(thickness: 2),
                        ],
                      );
                    },
                  ),

                  // Family Tasks Section - only show if user has a family
                  if (familyId != null && _familyTasksStream != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _familyTasksStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final tasks = snapshot.data!.docs
                            .map((doc) => _convertDocumentToTask(doc))
                            .toList();
                        return Column(
                          children: [
                            _buildTaskList(
                                tasks, false, 'Family Pending Tasks'),
                            _buildTaskList(
                                tasks, true, 'Family Completed Tasks'),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
      bottomNavigationBar: const BottomNavBar(),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Family Management button - show only if the user is a creator and has a family
          _buildFamilyManagementButton(),
          const SizedBox(width: 16),
          // Add New Task button
          FloatingActionButton(
            heroTag: 'addTask',
            onPressed: _showAddTaskDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
