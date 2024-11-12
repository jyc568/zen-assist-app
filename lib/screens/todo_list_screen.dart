import 'package:flutter/material.dart';
import 'package:zen_assist/managers/family_invites.dart';
import 'package:zen_assist/managers/family_management.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';
import 'package:zen_assist/widgets/task_card.dart';
import 'package:zen_assist/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';
import 'package:zen_assist/screens/task_detail_view_screen.dart'; // Updated import for new screen

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
  List<Map<String, dynamic>> familyMembers = [];

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

          // Load family members if user has a family
          if (familyId != null) {
            final familySnapshot = await _firestore
                .collection('users')
                .where('familyId', isEqualTo: familyId)
                .where('role', isNotEqualTo: 'creator') // Exclude creators
                .get();

            setState(() {
              familyMembers = familySnapshot.docs
                  .map((doc) => {
                        'id': doc.id,
                        'name': doc.data()['name'] ?? 'Unknown',
                        'email': doc.data()['email'] ?? 'No email'
                      })
                  .toList();
            });
          }
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
      assignedTo: data['assignedTo'],
      description: data['description'],
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
        if (taskType == 'family') {
          if (!isCreator) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Only family creators can create family tasks')),
            );
            return;
          }
          if (familyId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'You must be part of a family to create family tasks')),
            );
            return;
          }

          if (assignedTo == 'all') {
            // Create a task for each family member
            for (var member in familyMembers) {
              await _firestore.collection('todoList').add({
                'title': title,
                'dueDate': Timestamp.fromDate(dueDate),
                'isCompleted': false,
                'userId': member['id'], // Use ID for the database
                'createdAt': FieldValue.serverTimestamp(),
                'familyId': familyId,
                'taskType': 'family',
                'assignedTo': member['email'], // Store email for display
                'priority': priority,
                'description': description ?? '',
              });
            }
          } else {
            // Find the user ID corresponding to the selected email
            final memberData = familyMembers.firstWhere(
              (member) => member['email'] == assignedTo,
              orElse: () => {'id': '', 'email': assignedTo},
            );

            await _firestore.collection('todoList').add({
              'title': title,
              'dueDate': Timestamp.fromDate(dueDate),
              'isCompleted': false,
              'userId': memberData['id'], // Use ID for the database
              'createdAt': FieldValue.serverTimestamp(),
              'familyId': familyId,
              'taskType': 'family',
              'assignedTo': assignedTo, // Store email for display
              'priority': priority,
              'description': description ?? '',
            });
          }
        } else {
          // Personal task
          await _firestore.collection('todoList').add({
            'title': title,
            'dueDate': Timestamp.fromDate(dueDate),
            'isCompleted': false,
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'taskType': 'personal',
            'priority': priority,
            'assignedTo': null,
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
    String taskType = 'personal';
    String priority = _selectedPriority;
    String? assignedTo;
    String? description;

    // Only show family option if user has a familyId
    List<String> taskTypes =
        familyId != null ? ['personal', 'family'] : ['personal'];
    List<String> priorities = ['low', 'medium', 'high'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool showAssigneeDropdown = taskType == 'family' && isCreator;

            return AlertDialog(
              title: const Text('Add New Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (value) {
                        newTaskTitle = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) {
                        description = value;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: taskType,
                      decoration: const InputDecoration(
                        labelText: 'Task Type',
                      ),
                      onChanged: (value) {
                        setState(() {
                          taskType = value!;
                          // Reset assignedTo when switching task types
                          if (taskType == 'personal') {
                            assignedTo = null;
                          }
                        });
                      },
                      items: taskTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                      ),
                      onChanged: (value) {
                        setState(() {
                          priority = value!;
                        });
                      },
                      items: priorities.map((String p) {
                        return DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    if (showAssigneeDropdown && familyMembers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: assignedTo,
                        decoration: const InputDecoration(
                          labelText: 'Assign To',
                        ),
                        hint: const Text('Select assignee'),
                        onChanged: (value) {
                          setState(() {
                            assignedTo = value;
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('All members'),
                          ),
                          ...familyMembers.map((member) {
                            return DropdownMenuItem<String>(
                              value:
                                  member['email'], // Using email instead of ID
                              child: Text(member['email']),
                            );
                          }).toList(),
                        ],
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2025),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        'Due Date: ${selectedDate.toString().split(' ')[0]}',
                      ),
                    ),
                  ],
                ),
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
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailViewScreen(
                          task: task), // Navigating to new screen
                    ),
                  );
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
                  if (familyId != null) FamilyInvites(),
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
          _buildFamilyManagementButton(),
          const SizedBox(width: 16),
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
