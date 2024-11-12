// family_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyManagement extends StatefulWidget {
  final String familyId;
  final bool isCreator;

  const FamilyManagement({
    Key? key,
    required this.familyId,
    required this.isCreator,
  }) : super(key: key);

  @override
  _FamilyManagementState createState() => _FamilyManagementState();
}

class _FamilyManagementState extends State<FamilyManagement> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _familyMembers = [];
  List<Map<String, dynamic>> _pendingInvites = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
    _loadPendingInvites();
  }

  Future<void> _loadFamilyMembers() async {
    final members = await _firestore
        .collection('users')
        .where('familyId', isEqualTo: widget.familyId)
        .get();

    setState(() {
      _familyMembers = members.docs
          .map((doc) => {
                'id': doc.id,
                'email': doc.data()['email'],
                'role': doc.data()['role'],
              })
          .toList();
    });
  }

  Future<void> _loadPendingInvites() async {
    final invites = await _firestore
        .collection('familyInvites')
        .where('familyId', isEqualTo: widget.familyId)
        .where('status', isEqualTo: 'pending')
        .get();

    setState(() {
      _pendingInvites = invites.docs
          .map((doc) => {
                'id': doc.id,
                'email': doc.data()['recipientEmail'],
                'timestamp': doc.data()['timestamp'],
              })
          .toList();
    });
  }

  Future<void> _inviteMember(String email) async {
    setState(() => _isLoading = true);

    try {
      // Check if user exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        throw 'User not found';
      }

      final targetUser = userQuery.docs.first;
      
      // Check if user is already in a family
      if (targetUser.data()['familyId'] != null) {
        throw 'User is already in a family';
      }

      // Check if invite already exists
      final existingInvite = await _firestore
          .collection('familyInvites')
          .where('recipientEmail', isEqualTo: email)
          .where('familyId', isEqualTo: widget.familyId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingInvite.docs.isNotEmpty) {
        throw 'Invitation already sent';
      }

      // Create invitation
      await _firestore.collection('familyInvites').add({
        'familyId': widget.familyId,
        'recipientEmail': email,
        'recipientId': targetUser.id,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $email')),
      );

      _loadPendingInvites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await _firestore.collection('familyInvites').doc(inviteId).delete();
      _loadPendingInvites();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling invite: $e')),
      );
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'familyId': null,
        'role': 'user',
      });
      _loadFamilyMembers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing member: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Management'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isCreator) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invite New Member',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (_emailController.text.isNotEmpty) {
                                      _inviteMember(_emailController.text);
                                      _emailController.clear();
                                    }
                                  },
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Invite'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Family Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _familyMembers.length,
                itemBuilder: (context, index) {
                  final member = _familyMembers[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(member['email']),
                    subtitle: Text(member['role']),
                    trailing: widget.isCreator && member['role'] != 'creator'
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _removeMember(member['id']),
                          )
                        : null,
                  );
                },
              ),
            ),
            if (widget.isCreator) ...[
              const SizedBox(height: 24),
              const Text(
                'Pending Invites',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: _pendingInvites.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No pending invites'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pendingInvites.length,
                        itemBuilder: (context, index) {
                          final invite = _pendingInvites[index];
                          return ListTile(
                            leading: const Icon(Icons.mail_outline),
                            title: Text(invite['email']),
                            subtitle: const Text('Pending'),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel_outlined),
                              color: Colors.red,
                              onPressed: () => _cancelInvite(invite['id']),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}