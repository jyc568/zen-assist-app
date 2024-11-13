import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminInboxScreen extends StatelessWidget {
  final List<Map<String, String>> messages = [
    {
      'title': 'New Feedback',
      'subtitle': 'There are new incoming feedback',
      'date': 'Nov 9, 2024',
      'content': 'Dear Admin, please check on the new feedback. Thank you.',
    },
    {
      'title': 'New User',
      'subtitle': 'Great News we have a new user',
      'date': 'Nov 8, 2024',
      'content': 'Well done admin, we have finally got a new user.',
    },
    {
      'title': 'New Feedback',
      'subtitle': 'There are new incoming feedback',
      'date': 'Nov 7, 2024',
      'content': 'Dear Admin, please check on the new feedback. Thank you.'
    },
  ];

  AdminInboxScreen() {
    // Log feature utilization for Inbox feature when this screen is accessed
    _logFeatureUsage('inbox');
  }

  // Function to log feature usage in Firestore
  void _logFeatureUsage(String featureName) {
    FirebaseFirestore.instance
        .collection('stats')
        .doc('featureUtilization')
        .update({
      featureName: FieldValue.increment(1),
    }).catchError((error) {
      print("Failed to log feature usage: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inbox'),
        backgroundColor: const Color.fromARGB(255, 153, 201, 180),
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _buildMessageCard(context, messages[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, Map<String, String> message) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        title: Text(
          message['title'] ?? '',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['subtitle'] ?? '',
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              message['date'] ?? '',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: () => _showMessageDetail(context, message),
      ),
    );
  }

  void _showMessageDetail(BuildContext context, Map<String, String> message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message['title'] ?? ''),
          content: Text(message['content'] ?? ''),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
