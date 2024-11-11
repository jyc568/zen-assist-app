import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zen_assist/screens/homepage.dart';
import 'package:zen_assist/screens/todo_list_screen.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> userTasks = [];
  List<Map<String, dynamic>> familyTasks = [];
  List<Map<String, dynamic>> filteredUserTasks = [];
  List<Map<String, dynamic>> filteredFamilyTasks = [];
  String username = '';
  String? familyId;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (userData.exists) {
        setState(() {
          username = userData.data()?['username'] ?? 'User';
          familyId = userData.data()?['familyId'];
        });
        _loadTasks();
      }
    }
  }
  Color _getTaskColor(String priority) {
    return TaskPriorityColors.getColor(priority);
  }

   Future<void> _loadTasks() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      // Load personal tasks for the current user
      _firestore
          .collection('todoList')
          .where('userId', isEqualTo: user.uid)
          .where('taskType', isEqualTo: 'personal') // Only personal tasks
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          userTasks = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'title': doc.data()['title'] ?? '',
                    'description': doc.data()['description'] ?? '',
                    'priority': doc.data()['priority'] ?? 'low',
                    'color': _getTaskColor(doc.data()['priority'] ?? 'low'),
                    'createdAt': doc.data()['createdAt'],
                    'userId': doc.data()['userId'],
                    'completed': doc.data()['isCompleted'] ?? false,
                  })
              .toList();
          _filterTasks();
        });
      });

      // Load family tasks if user has a familyId
      if (familyId != null) {
        _firestore
            .collection('todoList')
            .where('familyId', isEqualTo: familyId)
            .where('taskType', isEqualTo: 'family') // Only family tasks
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen((snapshot) {
          setState(() {
            familyTasks = snapshot.docs
                .map((doc) => {
                      'id': doc.id,
                      'title': doc.data()['title'] ?? '',
                      'description': doc.data()['description'] ?? '',
                      'priority': doc.data()['priority'] ?? 'low',
                      'color': _getTaskColor(doc.data()['priority'] ?? 'low'),
                      'createdAt': doc.data()['createdAt'],
                      'userId': doc.data()['userId'],
                      'familyId': doc.data()['familyId'],
                      'completed': doc.data()['isCompleted'] ?? false,
                      'createdBy': doc.data()['createdBy'] ?? '',
                    })
                .toList();
            _filterTasks();
          });
        });
      }
    }
  }

 void _filterTasks() {
    setState(() {
      // Filter personal tasks based on searchQuery
      filteredUserTasks = userTasks.where((task) {
        final title = task['title']?.toString().toLowerCase() ?? '';
        final description = task['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();

        return title.contains(query) || description.contains(query);
      }).toList();

      // Filter family tasks based on searchQuery
      filteredFamilyTasks = familyTasks.where((task) {
        final title = task['title']?.toString().toLowerCase() ?? '';
        final description = task['description']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();

        return title.contains(query) || description.contains(query);
      }).toList();
    });
  }

  void _navigateToTaskDetails(String taskId, bool isFamilyTask) {
    // Navigate to task details screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(
          taskId: taskId,
          isFamilyTask: isFamilyTask,
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: const TextField(
            decoration: InputDecoration(
              hintText: 'Enter your feedback here...',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () {
                // Implement feedback sending logic
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            // User Profile Section
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      // Handle notifications
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search tasks...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _filterTasks();
                      });
                    },
                  ),

                  // Quick Actions
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickAction(Icons.search, 'Search'),
                      _buildQuickAction(Icons.download, 'Download'),
                      _buildQuickAction(Icons.calendar_today, 'Calendar'),
                    ],
                  ),
                ],
              ),
            ),

            // Tasks Lists
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Personal Tasks Section
                  _buildSectionHeader('My Tasks'),
                  ...filteredUserTasks.map((task) => _buildTaskItem(
                        task['title'] ?? '',
                        task['color'] as Color,
                        () => _navigateToTaskDetails(task['id'], false),
                      )),

                  const SizedBox(height: 24),

                  // Family Tasks Section
                  if (familyId != null) ...[
                    _buildSectionHeader('Family Tasks'),
                    ...filteredFamilyTasks.map((task) => _buildTaskItem(
                          task['title'] ?? '',
                          task['color'] as Color,
                          () => _navigateToTaskDetails(task['id'], true),
                        )),
                  ],

                  const SizedBox(height: 24),

                  // Feedback Button
                  _buildFeedbackButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            title == 'My Tasks' ? Icons.person : Icons.people,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton() {
    return InkWell(
      onTap: _showFeedbackDialog,
      child: Row(
        children: [
          Icon(Icons.help_outline, color: Colors.grey[600]),
          const SizedBox(width: 8),
          const Text('Feedback'),
        ],
      ),
    );
  }
}

// TaskDetailsScreen widget (placeholder - implement according to your needs)
class TaskDetailsScreen extends StatelessWidget {
  final String taskId;
  final bool isFamilyTask;

  const TaskDetailsScreen({
    Key? key,
    required this.taskId,
    required this.isFamilyTask,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isFamilyTask ? 'Family Task Details' : 'Task Details'),
      ),
      body: Center(
        child: Text('Task ID: $taskId'),
      ),
    );
  }
}
