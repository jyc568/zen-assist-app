import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

import 'package:zen_assist/widgets/bottom_nav_bar.dart';

class WeeklyMealPlanPage extends StatefulWidget {
  const WeeklyMealPlanPage({super.key});

  @override
  _WeeklyMealPlanPageState createState() => _WeeklyMealPlanPageState();
}

DateTime _lastLoadedDate = DateTime.now();

class _WeeklyMealPlanPageState extends State<WeeklyMealPlanPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: 'AIzaSyBW5SdgUyQ7eZGvS6DJPTr_zShShqIFA4c',
  );

  late DateTime _selectedWeekStart;
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  Map<String, Map<String, String>> _weeklyMealPlan = {};
  Map<String, String> _documentIds = {}; // Store Firestore document IDs
  List<String> _weekDays = [];

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeWeek();
    _loadWeeklyMealPlan();
  }

  void _initializeWeek() {
    // Get today's date
    final now = DateTime.now();
    // If there's a saved date in shared preferences, use that instead
    _selectedWeekStart = now.subtract(Duration(days: now.weekday - 1));
    _lastLoadedDate = _selectedWeekStart;

    // Generate week days
    _updateWeekDays();
  }

  void _updateWeekDays() {
    _weekDays = List.generate(7, (index) {
      final day = _selectedWeekStart.add(Duration(days: index));
      return DateFormat('E, MMM d').format(day);
    });
  }

  Future<void> _loadWeeklyMealPlan() async {
    setState(() => _isLoading = true);

    try {
      // Calculate the exact start and end of the selected week
      final weekStart = DateTime(_selectedWeekStart.year,
          _selectedWeekStart.month, _selectedWeekStart.day);
      final weekEnd = weekStart.add(const Duration(days: 7));

      print(
          'Loading meals from ${DateFormat('yyyy-MM-dd').format(weekStart)} to ${DateFormat('yyyy-MM-dd').format(weekEnd)}');

      // Initialize empty plan for each day
      Map<String, Map<String, String>> weekPlan = {};
      Map<String, String> docIds = {};

      // Initialize all days in the week with empty meals
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        weekPlan[dateStr] = {
          'breakfast': '',
          'lunch': '',
          'dinner': '',
          'snacks': '',
        };
      }

      // Query Firestore for the current week's meal plans
      final snapshot = await _firestore
          .collection('mealplans')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      print('Found ${snapshot.docs.length} meal plans for the week');

      // Fill in existing plans
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        print('Processing meal plan for date: $dateStr');

        weekPlan[dateStr] = {
          'breakfast': data['breakfast']?.toString() ?? '',
          'lunch': data['lunch']?.toString() ?? '',
          'dinner': data['dinner']?.toString() ?? '',
          'snacks': data['snacks']?.toString() ?? '',
        };

        docIds[dateStr] = doc.id;
      }

      if (mounted) {
        setState(() {
          _weeklyMealPlan = weekPlan;
          _documentIds = docIds;
          _lastLoadedDate = weekStart;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading meal plan: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meal plans: $e')),
        );
      }
    }
  }

  Future<void> _saveMealPlan(
      String dateStr, String mealType, String meal) async {
    try {
      setState(() => _isLoading = true);

      // Parse the date string to DateTime
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);

      // Ensure we're saving with the correct time (start of day)
      final normalizedDate = DateTime(date.year, date.month, date.day);

      if (_documentIds.containsKey(dateStr)) {
        // Update existing document
        await _firestore
            .collection('mealplans')
            .doc(_documentIds[dateStr])
            .update({
          mealType.toLowerCase(): meal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document with normalized date
        final docRef = await _firestore.collection('mealplans').add({
          'userId': _auth.currentUser?.uid,
          'date': Timestamp.fromDate(normalizedDate),
          mealType.toLowerCase(): meal,
          'breakfast': mealType == 'breakfast' ? meal : '',
          'lunch': mealType == 'lunch' ? meal : '',
          'dinner': mealType == 'dinner' ? meal : '',
          'snacks': mealType == 'snacks' ? meal : '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _documentIds[dateStr] = docRef.id;
      }

      // Update local state
      if (_weeklyMealPlan[dateStr] == null) {
        _weeklyMealPlan[dateStr] = {
          'breakfast': '',
          'lunch': '',
          'dinner': '',
          'snacks': '',
        };
      }
      _weeklyMealPlan[dateStr]![mealType.toLowerCase()] = meal;

      // Reload the week's data to ensure everything is in sync
      await _loadWeeklyMealPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal plan saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving meal plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving meal plan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<String>> _getAIRecommendations(String mealType) async {
    try {
      // Analyze user's past meal preferences
      final userPreferences = await _analyzePastMealPreferences(mealType);

      // Generate prompt for Gemini
      final prompt = '''
        Based on the user's past meal preferences: ${jsonEncode(userPreferences)},
        suggest 5 different ${mealType.toLowerCase()} options that are:
        1. Healthy and balanced
        2. Similar to their preferences
        3. Easy to prepare
        4. Healthy and Commonly Found in Malaysian Cuisine
        Please provide only the names of the meals in a list format.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      // Parse response and extract meal suggestions
      final suggestions = response.text
              ?.split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), ''))
              .take(5)
              .toList() ??
          [];

      return suggestions;
    } catch (e) {
      print('Error getting AI recommendations: $e');
      return _getDefaultSuggestions(mealType);
    }
  }

  Future<List<String?>> _analyzePastMealPreferences(String mealType) async {
    final snapshot = await _firestore
        .collection('mealPlans')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('date', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()[mealType.toLowerCase()] as String?)
        .where((meal) => meal != null && meal.isNotEmpty)
        .toList();
  }

  List<String> _getDefaultSuggestions(String mealType) {
    // Fallback suggestions if AI fails
    final defaults = {
      'breakfast': [
        'Oatmeal with fruits',
        'Yogurt parfait',
        'Whole grain toast with eggs',
        'Smoothie bowl',
        'Pancakes with berries'
      ],
      'lunch': [
        'Grilled chicken salad',
        'Quinoa bowl',
        'Turkey sandwich',
        'Vegetable soup',
        'Tuna wrap'
      ],
      'dinner': [
        'Baked salmon',
        'Stir-fried vegetables',
        'Chicken breast with rice',
        'Pasta with marinara',
        'Vegetable curry'
      ],
      'snacks': [
        'Mixed nuts',
        'Greek yogurt',
        'Apple with peanut butter',
        'Hummus with carrots',
        'Trail mix'
      ],
    };
    return defaults[mealType.toLowerCase()] ?? [];
  }

  Future<void> _deleteMeal(String dateStr, String mealType) async {
    try {
      if (_documentIds.containsKey(dateStr)) {
        await _firestore
            .collection('mealPlans')
            .doc(_documentIds[dateStr])
            .update({
          mealType.toLowerCase(): '',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _weeklyMealPlan[dateStr]![mealType.toLowerCase()] = '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting meal: $e')),
      );
    }
  }

  void _showEditDeleteDialog(
      String dateStr, String mealType, String currentMeal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $mealType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Meal'),
              onTap: () {
                Navigator.pop(context);
                _showCustomMealInput(dateStr, mealType, currentMeal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Meal',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                _deleteMeal(dateStr, mealType);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMealPlanDialog(String dateStr, String mealType) async {
    final suggestions = await _getAIRecommendations(mealType);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $mealType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suggestions:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...suggestions.map((meal) => ListTile(
                  title: Text(meal),
                  onTap: () {
                    _saveMealPlan(dateStr, mealType.toLowerCase(), meal);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Show text input for custom meal
                _showCustomMealInput(dateStr, mealType);
                Navigator.pop(context);
              },
              child: const Text('Add Custom Meal'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCustomMealInput(String dateStr, String mealType,
      [String? initialValue]) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            initialValue != null ? 'Edit $mealType' : 'Add Custom $mealType'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter your $mealType',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _saveMealPlan(dateStr, mealType.toLowerCase(), controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _weekDays.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(_weekDays[index]),
              selected: _selectedDayIndex == index,
              onSelected: (selected) {
                setState(() => _selectedDayIndex = index);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealPlanCard() {
    final dateStr = DateFormat('yyyy-MM-dd')
        .format(_selectedWeekStart.add(Duration(days: _selectedDayIndex)));
    final dayPlan = _weeklyMealPlan[dateStr] ?? {};

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _mealTypes.map((mealType) {
            final meal = dayPlan[mealType.toLowerCase()] ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mealType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        if (meal.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _showEditDeleteDialog(
                              dateStr,
                              mealType,
                              meal,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              _showMealPlanDialog(dateStr, mealType),
                        ),
                      ],
                    ),
                  ],
                ),
                if (meal.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showEditDeleteDialog(
                      dateStr,
                      mealType,
                      meal,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 16),
                      child: Text(meal),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      'Tap + to add ${mealType.toLowerCase()}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                const Divider(),
              ],
            );
          }).toList(),
        ),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyMealPlan,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedWeekStart,
                firstDate: DateTime(2024),
                lastDate: DateTime(2025),
              );
              if (picked != null) {
                setState(() {
                  // Ensure we start from the beginning of the week
                  _selectedWeekStart =
                      picked.subtract(Duration(days: picked.weekday - 1));
                  _selectedDayIndex = 0;
                  _updateWeekDays();
                });
                await _loadWeeklyMealPlan();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDaySelector(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildMealPlanCard(),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
