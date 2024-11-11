import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zen_assist/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;
  final String additionalInfo;
  final Color priorityColor;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onComplete,
    required this.additionalInfo,
    required this.priorityColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due: ${DateFormat('MMM d, y').format(task.dueDate)}'),
            Text(additionalInfo),
          ],
        ),
        trailing: Checkbox(
          value: task.isCompleted,
          onChanged: (bool? value) {
            if (value != null) {
              onComplete();
            }
          },
        ),
      ),
    );
  }
}