import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';

//Everyone in the family should be notified upon the creation of a new task, along with its information.

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Stream for fetching invites for the current user
  Stream<QuerySnapshot> _getInvites() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('familyInvites')
        .where('recipientEmail', isEqualTo: user.email)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Stream for fetching notifications for the current user
  Stream<QuerySnapshot> _getNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('uid', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Method to handle invite acceptance or decline
  Future<void> _handleInvite(String inviteId, bool accept) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final inviteDoc =
          await _firestore.collection('familyInvites').doc(inviteId).get();

      if (inviteDoc.exists) {
        final inviteData = inviteDoc.data() as Map<String, dynamic>;
        final familyId = inviteData['familyId'];
        final senderId = inviteData['senderId'];

        // If senderId is null, use the current user's UID
        final userIdToUse = senderId ?? user.uid;

        if (accept) {
          // Update the user's `familyId` and `role` in the `users` collection
          await _firestore.collection('users').doc(user.uid).update({
            'familyId': familyId,
            'role': 'member', // Change role if necessary
          });

          // Create a notification for the family creator (sender)
          await _firestore.collection('notifications').add({
            'uid': userIdToUse,
            'type': 'family_invite_accepted',
            'message': 'You have successfully joined a family group',//${user.email} has accepted your family invitation
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Delete the invite from the `familyInvites` collection
        await _firestore.collection('familyInvites').doc(inviteId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(accept ? 'Joined family group' : 'Invitation declined'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Method to fetch user details based on senderId (or use current user)
  Future<Map<String, dynamic>?> _getUserDetails(String? senderId) async {
    try {
      final user = _auth.currentUser;
      final idToUse = senderId ?? user?.uid;

      if (idToUse == null) return null;

      DocumentSnapshot snapshot =
          await _firestore.collection('users').doc(idToUse).get();
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
    return null;
  }

  // StreamBuilder to display list of pending invites
  Widget _buildInvitesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getInvites(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final invites = snapshot.data?.docs ?? [];

        if (invites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No pending invites',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];
            final data = invite.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp;
            final senderId = data['senderId'];

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUserDetails(senderId), // Fetch sender details
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (userSnapshot.hasError || !userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final senderDetails = userSnapshot.data!;
                final senderName = senderDetails['name'] ?? 'Unknown';
                final senderRole = senderDetails['role'] ?? 'Unknown';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.family_restroom),
                    ),
                    title: Text('Family Invitation from $senderName'),
                    subtitle: Text(
                      'Role: $senderRole\nReceived: ${timestamp.toDate().toString().split('.')[0]}',
                    ),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                color: Colors.green,
                                onPressed: () => _handleInvite(invite.id, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                color: Colors.red,
                                onPressed: () =>
                                    _handleInvite(invite.id, false),
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // StreamBuilder to display notifications list
  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No notifications',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final data = notification.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp;
            final bool isRead = data['read'] ?? false;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey : Colors.blue,
                  child: Icon(
                    _getNotificationIcon(data['type']),
                    color: Colors.white,
                  ),
                ),
                title: Text(data['message']),
                subtitle: Text(
                  'Received: ${timestamp.toDate().toString().split('.')[0]}',
                ),
                onTap: () {
                  if (!isRead) {
                    _markNotificationAsRead(notification.id);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to get the icon based on notification type
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'family_invite_accepted':
        return Icons.family_restroom;
      case 'task_completed':
        return Icons.task_alt;
      case 'task_assigned':
        return Icons.assignment;
      default:
        return Icons.notifications;
    }
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // The UI of the inbox screen with the TabBar and BottomNavBar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notifications'),
            Tab(text: 'Invites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(),
          _buildInvitesList(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
