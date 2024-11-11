import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String? id;
  final String title;
  final DateTime dueDate;
  final bool isCompleted;
  final String userId;
  final String? familyId;  // To associate with family tasks
  final String taskType;  // To distinguish between 'individual' and 'family'
  final String priority;

  Task({
    this.id,
    required this.title,
    required this.dueDate,
    required this.isCompleted,
    required this.userId,
    this.familyId,
    required this.taskType,  
    this.priority = 'low',
  });

  // Convert Firestore Document to Task object
  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] ?? false,
      userId: data['userId'] ?? '',
      familyId: data['familyId'],  // Add familyId here if available
      taskType: data['taskType'] ?? 'individual',  // Add taskType field
    );
  }

  // Convert Task object to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': isCompleted,
      'userId': userId,
      'familyId': familyId,
      'taskType': taskType,  // Save taskType field
      'priority': priority,
    };
  }
}
