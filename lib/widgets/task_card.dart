import 'package:flutter/material.dart';
import 'package:zen_assist/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('Due: ${task.dueDate.toString().split(' ')[0]}'),
        trailing: Checkbox(
          value: task.isCompleted,
          onChanged: (value) => onComplete(),
        ),
      ),
    );
  }
}
