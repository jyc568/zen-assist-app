// family_invites.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyInvites extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FamilyInvites({Key? key}) : super(key: key);

  Stream<QuerySnapshot> _getInvites() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('familyInvites')
        .where('recipientEmail', isEqualTo: user.email)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _handleInvite(String inviteId, bool accept) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final invite =
          await _firestore.collection('familyInvites').doc(inviteId).get();

      if (accept) {
        final familyId = invite.data()?['familyId'];

        // Update user's family ID and role
        await _firestore.collection('users').doc(user.uid).update({
          'familyId': familyId,
          'role': 'member',
        });

        // Add user to the family members array
        await _firestore.collection('families').doc(familyId).update({
          'members': FieldValue.arrayUnion([user.uid]),
        });
      }

      // Delete the invitation
      await _firestore.collection('familyInvites').doc(inviteId).delete();
    } catch (e) {
      print('Error handling invite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getInvites(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading invites'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final invites = snapshot.data?.docs ?? [];

        if (invites.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Family Invites',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invites.length,
                itemBuilder: (context, index) {
                  final invite = invites[index];
                  return ListTile(
                    leading: const Icon(Icons.family_restroom),
                    title: const Text('Family Invitation'),
                    subtitle:
                        Text('You have been invited to join a family group'),
                    trailing: Row(
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
                          onPressed: () => _handleInvite(invite.id, false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
