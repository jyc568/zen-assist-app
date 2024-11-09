// bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:zen_assist/screens/mainpage.dart';
import 'package:zen_assist/screens/todo_list_screen.dart';
import 'package:zen_assist/screens/weeklymealplanpage.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        // Navigate to the corresponding screen based on the selected index
        switch (index) {
          case 0:
            // Navigate to MainPage using MaterialPageRoute
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MainPage()),
            );
            break;
          case 1:
            // Navigate to ToDoListScreen using MaterialPageRoute
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ToDoListScreen()),
            );
            break;
          case 2:
             Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WeeklyMealPlanPage()),
            );
          // Add more cases for additional navigation items
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'List',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.food_bank),
          label: 'Meal Planner',
        ),
        // Add more navigation items as needed
      ],
      // Debugging visual cue
      backgroundColor: Colors.blue,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
    );
  }
}
