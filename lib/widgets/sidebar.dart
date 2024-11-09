// sidebar.dart
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    // Debugging statement to confirm Sidebar is being built
    print("Sidebar is being built");

    return Drawer(
      child: ListView(
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text('Username'),
            accountEmail: null,
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('My Projects'),
            onTap: () {
              // Navigate to My Projects screen
              Navigator.pushNamed(context, '/my-projects');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Family Shared'),
            onTap: () {
              // Navigate to Family Shared screen
              Navigator.pushNamed(context, '/family-shared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Feedback'),
            onTap: () {
              // Navigate to Feedback screen
              Navigator.pushNamed(context, '/feedback');
            },
          ),
          // Debugging visual cue
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Sidebar is visible', // This text confirms the Sidebar is rendered
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
