import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(FeedbackApp());
}

class FeedbackApp extends StatelessWidget {
  FeedbackApp() {
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
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            hintText: 'Search by ID',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.green, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sort, color: Colors.grey),
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
            return Center(child: CircularProgressIndicator());
          }

          // Filter feedback based on search query
          var feedbackDocs = snapshot.data!.docs.where((doc) {
            return doc.id.contains(searchQuery);
          }).toList();

          return ListView(
            children: feedbackDocs.map((doc) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: FeedbackContainer(
                  id: doc.id,
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
  final String id;
  final String daysAgo;

  FeedbackContainer({required this.id, required this.daysAgo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackDetailPage(id: id),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Checkbox(
              value: false,
              onChanged: (bool? value) {},
              activeColor: Colors.green,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                id,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.sort,
              color: Colors.grey,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              daysAgo,
              style: TextStyle(
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
    return await FirebaseFirestore.instance
        .collection('feedback')
        .doc(id)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Feedback Details'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getFeedbackDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
            return Center(child: Text('Feedback not found'));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 80),
                Text(
                  'ID: ${id}',
                  style: TextStyle(
                    color: Colors.green[500],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.alternate_email,
                        color: Colors.grey[600], size: 16),
                    SizedBox(width: 4),
                    Text(
                      data['email'] ?? 'No email provided',
                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.title, color: Colors.grey[600], size: 16),
                    SizedBox(width: 4),
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
