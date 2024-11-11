import 'package:flutter/material.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';
import 'package:zen_assist/widgets/task_card.dart';
import 'package:zen_assist/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';

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

  Future<void> _addTask(String title, DateTime dueDate, String taskType, String priority) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Only allow family tasks if user is creator
        if (taskType == 'family' && !isCreator) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Only family creators can create family tasks')),
          );
          return;
        }

        await _firestore.collection('todoList').add({
          'title': title,
          'dueDate': Timestamp.fromDate(dueDate),
          'isCompleted': false,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'familyId': taskType == 'family' ? familyId : null,
          'taskType': taskType,
          'priority': priority,
        });
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: Column(
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
              const SizedBox(height: 16),
              if (isCreator &&
                  familyId != null) // Only show for family creators
                DropdownButtonFormField<String>(
                  value: taskType,
                  decoration: const InputDecoration(
                    labelText: 'Task Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'personal',
                      child: Text('Personal Task'),
                    ),
                    DropdownMenuItem(
                      value: 'family',
                      child: Text('Family Task'),
                    ),
                  ],
                  onChanged: (value) {
                    taskType = value!;
                  },
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                ),
                items: TaskPriorityColors.priorityColors.keys.map((String key) {
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newTaskTitle.isNotEmpty) {
                  _addTask(newTaskTitle, selectedDate, taskType,priority);
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
                additionalInfo:
                    task.taskType == 'family' ? 'Family Task' : 'Personal Task',
                    priorityColor: TaskPriorityColors.getColor(task.priority),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
