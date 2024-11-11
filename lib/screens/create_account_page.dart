import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _familyId; // Store the familyId if user chooses to join a family.
  bool _isCreatingFamily = false; // Flag to track if the user is creating a family.

  // Show dialog for choosing family creation or joining an existing one
  void _showFamilyOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Family Setup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Create a new family'),
                leading: Radio<bool>(
                  value: true,
                  groupValue: _isCreatingFamily,
                  onChanged: (value) {
                    setState(() {
                      _isCreatingFamily = value!;
                      _familyId = null; // Reset familyId if creating new family.
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Join an existing family'),
                leading: Radio<bool>(
                  value: false,
                  groupValue: _isCreatingFamily,
                  onChanged: (value) {
                    setState(() {
                      _isCreatingFamily = value!;
                    });
                    Navigator.pop(context);
                    _showFamilyIdDialog();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show dialog for entering familyId when joining an existing family
  void _showFamilyIdDialog() {
    String familyIdInput = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Family ID'),
          content: TextField(
            onChanged: (value) {
              familyIdInput = value;
            },
            decoration: const InputDecoration(hintText: 'Enter Family ID'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Check if the family exists
                var familyDoc = await _firestore.collection('families').doc(familyIdInput).get();
                if (familyDoc.exists) {
                  setState(() {
                    _familyId = familyIdInput;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Joined the family successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Family ID not found.')),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  // Handle account creation logic
  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Step 1: Create a new user with Firebase Authentication
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Step 2: Add user information to Firestore
        User? user = userCredential.user;
        if (user != null) {
          Map<String, dynamic> userData = {
            'name': _nameController.text,
            'email': _emailController.text,
            'uid': user.uid,
            'username': _usernameController.text,
            'createdAt': FieldValue.serverTimestamp(),
            'isVerified': user.emailVerified,
            'role': 'user',
          };

          // Handle family creation or joining
          if (_isCreatingFamily) {
            // Create new family
            final familyRef = _firestore.collection('families').doc();
            await familyRef.set({
              'uid': user.uid,
              'familyName': '${_nameController.text} Family', // Dynamic family name
              'members': [user.uid],
              'createdAt': FieldValue.serverTimestamp(),
            });

            userData['familyId'] = familyRef.id;
            userData['role'] = 'creator';
          } else if (_familyId != null) {
            // Join an existing family
            await _firestore.collection('families').doc(_familyId).update({
              'members': FieldValue.arrayUnion([user.uid]),
            });

            userData['familyId'] = _familyId;
            userData['role'] = 'member';
          }

          // Store the user data in Firestore
          await _firestore.collection('users').doc(user.uid).set(userData);

          // Optionally, send a verification email
          await user.sendEmailVerification();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully!')),
          );

          // Navigate to home or login page
          Navigator.pop(context); // Or navigate to next screen.
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Something went wrong!';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'The email address is already in use.';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your Username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showFamilyOptionsDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Choose Family Option',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
