import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';
import 'package:zen_assist/widgets/sidebar.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final Color color;
  final String userId;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.color = Colors.blue,
    required this.userId,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      color: Color(map['colorValue']),
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'colorValue': color.value,
      'userId': userId,
    };
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  DateTime _selectedDate = DateTime.now();
  List<CalendarEvent> _calendarEvents = [];
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _eventTitle;
  DateTime? _eventDateTime;

  @override
  void initState() {
    super.initState();
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    if (_auth.currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endOfMonth =
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final snapshot = await _firestore
          .collection('events')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('dateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('dateTime')
          .get();

      _calendarEvents = snapshot.docs
          .map((doc) => CalendarEvent.fromMap(doc.data()))
          .toList();

      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Error loading events: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCalendarEvent() async {
    if (_eventTitle == null || _eventDateTime == null) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    try {
      final newEvent = CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _eventTitle!,
        dateTime: _eventDateTime!,
        userId: _auth.currentUser!.uid,
      );

      await _firestore
          .collection('events')
          .doc(newEvent.id)
          .set(newEvent.toMap());

      // Clear input fields and reload events
      _eventTitle = null;
      _eventDateTime = null;
      await _loadCalendarEvents();
      _showSuccessSnackBar('Event added successfully');
    } catch (e) {
      _showErrorSnackBar('Error saving event: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      bottomNavigationBar: const BottomNavBar(),
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          _buildCalendarHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: _buildCalendarGrid(),
                      ),
                      if (_calendarEvents.isNotEmpty)
                        Expanded(
                          child: _buildEventList(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(_selectedDate),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month - 1,
                  _selectedDate.day,
                );
              });
              _loadCalendarEvents();
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month + 1,
                  _selectedDate.day,
                );
              });
              _loadCalendarEvents();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final date = _getDateForIndex(index);
        final events = _getEventsForDate(date);
        final isToday = _isToday(date);
        final isSelectedMonth = date.month == _selectedDate.month;

        return GestureDetector(
          onTap: () => _showAddEventDialog(date),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isToday ? Colors.blue : Colors.grey[300]!,
                width: isToday ? 2 : 1,
              ),
              color: isSelectedMonth ? Colors.white : Colors.grey[100],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelectedMonth ? Colors.black : Colors.grey,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                ...events.map((event) => _buildEventIndicator(event)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventIndicator(CalendarEvent event) {
    return Positioned(
      top: 20.0,
      left: 2,
      right: 2,
      child: Container(
        height: 15,
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Tooltip(
          message: event.title,
          child: Text(
            event.title,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildEventList() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Events',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _calendarEvents.length,
                itemBuilder: (context, index) {
                  final event = _calendarEvents[index];
                  return ListTile(
                    leading: Icon(Icons.event, color: event.color),
                    title: Text(event.title),
                    subtitle: Text(
                        DateFormat('MMM d, h:mm a').format(event.dateTime)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteCalendarEvent(event);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEventDialog(DateTime date) {
    _eventTitle = null;
    _eventDateTime = date;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Event for ${DateFormat('MMM d').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Event Title',
              ),
              onChanged: (value) {
                _eventTitle = value;
              },
            ),
            TextButton(
              onPressed: () async {
                final pickedDateTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_eventDateTime!),
                );
                if (pickedDateTime != null) {
                  setState(() {
                    _eventDateTime = DateTime(
                      _eventDateTime!.year,
                      _eventDateTime!.month,
                      _eventDateTime!.day,
                      pickedDateTime.hour,
                      pickedDateTime.minute,
                    );
                  });
                }
              },
              child: Text(DateFormat('h:mm a').format(_eventDateTime!)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _addCalendarEvent,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  DateTime _getDateForIndex(int index) {
    final firstDayOfMonth =
        DateTime(_selectedDate.year, _selectedDate.month, 1);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final firstDisplayedDate =
        firstDayOfMonth.subtract(Duration(days: firstDayWeekday - 1));
    return firstDisplayedDate.add(Duration(days: index));
  }


  List<CalendarEvent> _getEventsForDate(DateTime date) {
    return _calendarEvents
        .where((event) =>
            event.dateTime.year == date.year &&
            event.dateTime.month == date.month &&
            event.dateTime.day == date.day)
        .toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _deleteCalendarEvent(CalendarEvent event) async {
    try {
      await _firestore.collection('events').doc(event.id).delete();
      await _loadCalendarEvents();
      _showSuccessSnackBar('Event deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting event: $e');
    }
  }
}
