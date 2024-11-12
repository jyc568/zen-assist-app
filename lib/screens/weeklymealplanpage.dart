import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';
import 'package:table_calendar/table_calendar.dart';

//WeeklyMealPlanPage could use some work, GEMINI API hasnt been added yet

class WeeklyMealPlanPage extends StatefulWidget {
  const WeeklyMealPlanPage({super.key});

  @override
  _WeeklyMealPlanPageState createState() => _WeeklyMealPlanPageState();
}

bool _isCreateMode = false;
final _formKey = GlobalKey<FormState>();
final TextEditingController _breakfastController = TextEditingController();
final TextEditingController _lunchController = TextEditingController();
final TextEditingController _dinnerController = TextEditingController();
final TextEditingController _snacksController = TextEditingController();

class _WeeklyMealPlanPageState extends State<WeeklyMealPlanPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _mealPlanStream;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _initializeMealPlanStream();
    _checkAndCreateTodayMealPlan();
    _scheduleCleanup();
  }

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _snacksController.dispose();
    super.dispose();
  }

  bool _isDateValid(DateTime date) {
    final now = DateTime.now();
    return date.isAfter(DateTime(now.year, now.month, now.day - 1));
  }

  void _showCreateMealPlanDialog() {
    if (!_isDateValid(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create meal plan for past dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reset controllers
    _breakfastController.clear();
    _lunchController.clear();
    _dinnerController.clear();
    _snacksController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Create Meal Plan for ${_selectedDate.toString().split(' ')[0]}'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _breakfastController,
                    decoration: const InputDecoration(
                      labelText: 'Breakfast',
                      hintText: 'Enter breakfast meal',
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Please enter a breakfast meal'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lunchController,
                    decoration: const InputDecoration(
                      labelText: 'Lunch',
                      hintText: 'Enter lunch meal',
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Please enter a lunch meal'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dinnerController,
                    decoration: const InputDecoration(
                      labelText: 'Dinner',
                      hintText: 'Enter dinner meal',
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Please enter a dinner meal'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _snacksController,
                    decoration: const InputDecoration(
                      labelText: 'Snacks',
                      hintText: 'Enter snacks (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await _createCustomMealPlan();
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createCustomMealPlan() async {
    try {
      final selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      // Check if a meal plan already exists for this date
      final existingPlan = await _firestore
          .collection('mealPlans')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('date', isEqualTo: selectedDate)
          .get();

      if (existingPlan.docs.isNotEmpty) {
        // Update existing meal plan
        await existingPlan.docs.first.reference.update({
          'breakfast': _breakfastController.text,
          'lunch': _lunchController.text,
          'dinner': _dinnerController.text,
          'snacks': _snacksController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new meal plan
        await _firestore.collection('mealPlans').add({
          'userId': _auth.currentUser?.uid,
          'date': selectedDate,
          'breakfast': _breakfastController.text,
          'lunch': _lunchController.text,
          'dinner': _dinnerController.text,
          'snacks': _snacksController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal plan created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating meal plan: $e')),
        );
      }
    }
  }

  void _initializeMealPlanStream() {
    final startOfWeek =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    _mealPlanStream = _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('date', isGreaterThanOrEqualTo: startOfWeek)
        .where('date', isLessThan: endOfWeek)
        .orderBy('date')
        .snapshots();
  }

  void _scheduleCleanup() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('date', isLessThan: thirtyDaysAgo)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  Future<void> _checkAndCreateTodayMealPlan() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final snapshot = await _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('date', isEqualTo: today)
        .get();

    if (snapshot.docs.isEmpty) {
      await _firestore.collection('mealPlans').add({
        'userId': _auth.currentUser?.uid,
        'date': today,
        'breakfast': '',
        'lunch': '',
        'dinner': '',
        'snacks': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Map<String, dynamic>?> _getMealPlanForDate(DateTime date) async {
    final snapshot = await _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('date', isEqualTo: date)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  Future<void> _updateMealPlan(String type, String meal) async {
    try {
      final selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final snapshot = await _firestore
          .collection('mealPlans')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('date', isEqualTo: selectedDate)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          type.toLowerCase(): meal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('mealPlans').add({
          'userId': _auth.currentUser?.uid,
          'date': selectedDate,
          type.toLowerCase(): meal,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meal plan: $e')),
      );
    }
  }

  Future<void> _copyMealPlan(DateTime fromDate, DateTime toDate) async {
    final mealPlan = await _getMealPlanForDate(fromDate);
    if (mealPlan != null) {
      await _firestore.collection('mealPlans').add({
        'userId': _auth.currentUser?.uid,
        'date': toDate,
        'breakfast': mealPlan['breakfast'],
        'lunch': mealPlan['lunch'],
        'dinner': mealPlan['dinner'],
        'snacks': mealPlan['snacks'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal plan copied successfully!')),
      );
    }
  }

  Future<Map<String, dynamic>> _generateWeeklyStats() async {
    final startOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final snapshot = await _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('date', isGreaterThanOrEqualTo: startOfWeek)
        .where('date', isLessThan: endOfWeek)
        .get();

    int totalMeals = 0;
    Map<String, int> mealTypeCount = {
      'breakfast': 0,
      'lunch': 0,
      'dinner': 0,
      'snacks': 0,
    };

    for (var doc in snapshot.docs) {
      final data = doc.data();
      for (var type in mealTypeCount.keys) {
        if (data[type] != null && data[type].toString().isNotEmpty) {
          mealTypeCount[type] = (mealTypeCount[type] ?? 0) + 1;
          totalMeals++;
        }
      }
    }

    return {
      'totalMeals': totalMeals,
      'mealTypeCount': mealTypeCount,
      'completionRate': (totalMeals / (snapshot.docs.length * 4) * 100).round(),
    };
  }

  Future<List<String>> _generateMealSuggestions(String mealType) async {
    final snapshot = await _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('date', descending: true)
        .limit(10)
        .get();

    final meals = snapshot.docs
        .map((doc) => (doc.data())[mealType.toLowerCase()])
        .where((meal) => meal != null && meal.toString().isNotEmpty)
        .toSet()
        .toList();

    if (meals.length < 3) {
      meals.addAll(_getDefaultSuggestions(mealType));
    }

    return meals.take(5).cast<String>().toList();
  }

  List<String> _getDefaultSuggestions(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return [
          'Oatmeal with fruits and nuts',
          'Yogurt parfait',
          'Whole grain toast with avocado',
          'Smoothie bowl',
          'Eggs and vegetables'
        ];
      case 'lunch':
        return [
          'Grilled chicken salad',
          'Quinoa bowl',
          'Turkey wrap',
          'Mediterranean pasta',
          'Vegetable soup with bread'
        ];
      case 'dinner':
        return [
          'Salmon with roasted vegetables',
          'Stir-fry with brown rice',
          'Lean beef with sweet potato',
          'Baked chicken with quinoa',
          'Vegetarian curry'
        ];
      case 'snacks':
        return [
          'Mixed nuts and dried fruits',
          'Greek yogurt with berries',
          'Apple with almond butter',
          'Hummus with vegetables',
          'Trail mix'
        ];
      default:
        return [];
    }
  }

  void _showWeeklyStats() async {
    final stats = await _generateWeeklyStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weekly Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Meals Planned: ${stats['totalMeals']}'),
            Text('Completion Rate: ${stats['completionRate']}%'),
            const SizedBox(height: 8),
            const Text('Meals by Type:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...(stats['mealTypeCount'] as Map<String, int>).entries.map(
                  (e) => Text('${e.key}: ${e.value}'),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMealSuggestions() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Meal Suggestions'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<Map<String, List<String>>>(
              future: Future.wait([
                _generateMealSuggestions('Breakfast'),
                _generateMealSuggestions('Lunch'),
                _generateMealSuggestions('Dinner'),
                _generateMealSuggestions('Snacks'),
              ]).then((results) => {
                    'Breakfast': results[0],
                    'Lunch': results[1],
                    'Dinner': results[2],
                    'Snacks': results[3],
                  }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final suggestions = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: suggestions.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...entry.value.map((meal) => ListTile(
                                title: Text(meal),
                                onTap: () {
                                  _updateMealPlan(entry.key, meal);
                                  Navigator.pop(context);
                                },
                              )),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCopyDialog() {
    DateTime targetDate = _selectedDate;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Copy Meal Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select target date:'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: targetDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null && context.mounted) {
                    targetDate = picked;
                  }
                },
                child: const Text('Pick Date'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _copyMealPlan(_selectedDate, targetDate);
                Navigator.pop(context);
              },
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDate = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildMealPlanCard(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final isSelected = _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: isSelected
            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat.yMMMd().format(date),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Breakfast: ${data['breakfast'] ?? 'N/A'}'),
              Text('Lunch: ${data['lunch'] ?? 'N/A'}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dinner: ${data['dinner'] ?? 'N/A'}'),
              Text('Snacks: ${data['snacks'] ?? 'N/A'}'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateMealPlanDialog,
            tooltip: 'Create custom meal plan',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _showCopyDialog(),
            tooltip: 'Copy meal plan',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showWeeklyStats,
            tooltip: 'Weekly statistics',
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showMealSuggestions,
            tooltip: 'Meal suggestions',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarView(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _mealPlanStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMealPlanCard(docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
