import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zen_assist/screens/adminhomepage.dart';
import 'create_account_page.dart';
import 'mainpage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Show loading indicator when signing in
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      // Use Firebase Authentication to sign in
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // If successful, navigate based on user role in Firestore
      if (userCredential.user != null) {
        // Fetch user document from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        // Check if document exists
        if (userDoc.exists) {
          String? role = userDoc['role']; // Access the role field

          if (role == 'admin') {
            // Navigate to the AdminPage for admin
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => Adminhomepage()),
              (route) => false, // Clear the stack and open AdminPage
            );
          } else {
            // Navigate to the MainPage for regular users
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainPage()),
              (route) => false, // Clear the stack and open MainPage
            );
          }
        } else {
          // If document does not exist, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User data not found in Firestore.')),
          );
        }
      }
    } catch (e) {
      // Handle errors (e.g., invalid credentials)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
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
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // The login button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null // Disable the button while loading
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _login(); // Call the login function
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        ) // Show loading indicator when signing in
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreateAccountPage()),
                    );
                  },
                  child: const Text('Create New Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
