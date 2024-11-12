import 'package:flutter/material.dart';

// Define task priority colors as a constant map
class TaskPriorityColors {
  static const Map<String, Color> priorityColors = {
    'high': Color(0xFFFF4444),    // Red for high priority
    'medium': Color(0xFFFFAA00),  // Orange for medium priority
    'low': Color(0xFF4CAF50),     // Green for low priority
  };

  static Color getColor(String priority) {
    return priorityColors[priority.toLowerCase()] ?? Colors.grey;
  }
}
