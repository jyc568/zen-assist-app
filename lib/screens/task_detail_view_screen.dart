import 'package:flutter/material.dart';
import 'package:zen_assist/models/task.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskDetailViewScreen extends StatelessWidget {
  final Task task;

  const TaskDetailViewScreen({super.key, required this.task});

  // Function to fetch the email of the assigned user
  Future<String> _getAssignedUserEmail(String userId) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userSnapshot.exists) {
        return userSnapshot.data()?['email'] ?? 'Email not found';
      } else {
        return 'User not found';
      }
    } catch (e) {
      print("Error fetching user email: $e");
      return 'Error fetching email';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Due Date: ${task.dueDate.toLocal()}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Priority: ${task.priority.toUpperCase()}',
              style: TextStyle(
                fontSize: 18,
                color: TaskPriorityColors.getColor(task
                    .priority), // Using the existing logic for priority color
              ),
            ),
            const SizedBox(height: 16),
            // FutureBuilder to fetch the assigned user's email
            task.assignedTo != null
                ? FutureBuilder<String>(
                    future: _getAssignedUserEmail(task.assignedTo!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        return Text(
                          'Assigned To: ${snapshot.data}',
                          style: const TextStyle(fontSize: 18),
                        );
                      } else {
                        return const Text(
                          'Assigned To: Unassigned',
                          style: TextStyle(fontSize: 18),
                        );
                      }
                    },
                  )
                : const Text(
                    'Assigned To: Unassigned',
                    style: TextStyle(fontSize: 18),
                  ),
            const SizedBox(height: 16),
            Text(
              'Description: ${task.description ?? 'No description provided.'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Task Type: ${task.taskType == 'family' ? 'Family' : 'Personal'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${task.isCompleted ? 'Completed' : 'Pending'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
