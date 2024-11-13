import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(FeedbackApp());
}

class FeedbackApp extends StatelessWidget {
  FeedbackApp() {
    // Log feature utilization for Feedback feature when this screen is accessed
    _logFeatureUsage('feedbackmain');
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
    return MaterialApp(
      title: 'Feedback',
      home: FeedbackListPage(),
    );
  }
}

class FeedbackListPage extends StatefulWidget {
  @override
  _FeedbackListPageState createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends State<FeedbackListPage> {
  bool isAscending = true;
  String searchQuery = '';

  void _toggleSortOrder() {
    setState(() {
      isAscending = !isAscending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            hintText: 'Search by ID',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.green, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.grey),
            onPressed: _toggleSortOrder,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('feedback')
            .orderBy('timestamp', descending: !isAscending)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filtered list based on search query
          var feedbackDocs = snapshot.data!.docs.where((doc) {
            return doc['id'].toString().contains(searchQuery);
          }).toList();

          return ListView(
            children: feedbackDocs.map((doc) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Adds space on the left and right
                child: FeedbackContainer(
                  documentId: doc.id, // Firestore document ID for navigation
                  displayId: doc['id'].toString(), // Field `id` for display
                  daysAgo: _getTimeAgo(doc['timestamp']),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // Helper function to convert Firestore timestamp to days ago
  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final feedbackDate = timestamp.toDate();
    final difference = now.difference(feedbackDate).inDays;
    return difference == 0 ? 'Today' : '$difference days ago';
  }
}

class FeedbackContainer extends StatelessWidget {
  final String documentId; // Firestore document ID
  final String displayId; // Display `id` field from the document
  final String daysAgo;

  FeedbackContainer(
      {required this.documentId,
      required this.displayId,
      required this.daysAgo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackDetailPage(
                id: documentId), // Pass document ID for navigation
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Checkbox(
              value: false,
              onChanged: (bool? value) {},
              activeColor: Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayId, // Display the `id` field from the document data
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.sort,
              color: Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              daysAgo,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackDetailPage extends StatelessWidget {
  final String id;

  FeedbackDetailPage({required this.id});

  Future<DocumentSnapshot> _getFeedbackDetails() async {
    try {
      return await FirebaseFirestore.instance
          .collection('feedback')
          .doc(id)
          .get();
    } catch (e) {
      print('Error fetching feedback details: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Feedback Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getFeedbackDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Feedback not found'));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80), // Space above the content
                Text(
                  'ID: ${data['id']}', // Use the id from the document field
                  style: TextStyle(
                    color: Colors.green[500],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.alternate_email,
                        color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      data['email'] ?? 'No email provided',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.title, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      data['title'] ?? 'No title',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                  ],
                ),
                Divider(color: Colors.green[200], height: 32),
                Text(
                  data['message'] ?? 'No feedback provided',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
