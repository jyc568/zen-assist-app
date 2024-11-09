// task.dart
class Task {
  final String? id;  // Add this line
  final String title;
  final DateTime dueDate;
  bool isCompleted;
  final String userId;

  Task({
    this.id,  // Add this line
    required this.title,
    required this.dueDate,
    required this.isCompleted,
    required this.userId,
  });
}