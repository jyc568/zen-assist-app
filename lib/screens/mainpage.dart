import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:zen_assist/widgets/bottom_nav_bar.dart';
import 'package:zen_assist/widgets/sidebar.dart';
import 'package:zen_assist/utils/task_priority_colors.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final DateTime? endDateTime;
  final String priority;
  final String userId;
  final String? description;
  final bool? isRecurring;
  final String? recurringPattern;
  final String? tags;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.endDateTime,
    required this.priority,
    required this.userId,
    this.description,
    this.isRecurring,
    this.recurringPattern,
    this.tags,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(
          (map['dateTime'] as Timestamp).millisecondsSinceEpoch),
      endDateTime: map['endDateTime'] != null
          ? (map['endDateTime'] as Timestamp).toDate()
          : null,
      priority: map['priority'],
      userId: map['userId'],
      description: map['description'],
      isRecurring: map['isRecurring'],
      recurringPattern: map['recurringPattern'],
      tags: map['tags'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'endDateTime':
          endDateTime != null ? Timestamp.fromDate(endDateTime!) : null,
      'priority': priority,
      'userId': userId,
      'description': description,
      'isRecurring': isRecurring,
      'recurringPattern': recurringPattern,
      'tags': tags,
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
  String? _eventPriority;
  String? _eventDescription;
  DateTime? _eventEndDateTime;
  bool? _eventIsRecurring;
  String? _eventRecurringPattern;
  String? _eventTags;

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

      print(
          'Loading events for user: ${_auth.currentUser!.uid}, Date Range: $startOfMonth to $endOfMonth');

      final snapshot = await _firestore
          .collection('events')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('dateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('dateTime')
          .get();

      // Debugging - log number of events fetched
      print("Fetched events: ${snapshot.docs.length}");

      _calendarEvents = snapshot.docs
          .map((doc) => CalendarEvent.fromMap(doc.data()))
          .toList();

      setState(() {}); // Trigger UI update
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

    // Check if the event date is in the past
    if (_eventDateTime!.isBefore(DateTime.now())) {
      _showErrorSnackBar('Event date cannot be in the past.');
      return;
    }

    try {
      final newEvent = CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _eventTitle!,
        dateTime: _eventDateTime!,
        endDateTime: _eventEndDateTime,
        priority: _eventPriority ?? 'medium',
        userId: _auth.currentUser!.uid,
        description: _eventDescription,
        isRecurring: _eventIsRecurring ?? false,
        recurringPattern: _eventRecurringPattern,
        tags: _eventTags,
      );

      await _firestore
          .collection('events')
          .doc(newEvent.id)
          .set(newEvent.toMap());

      void clearEventFields() {
        _eventTitle = null;
        _eventDateTime = null;
        _eventPriority = null;
        _eventDescription = null;
        _eventEndDateTime = null;
        _eventIsRecurring = null;
        _eventRecurringPattern = null;
        _eventTags = null;
      }

      // Reload events for the current month or date
      await _loadCalendarEvents();
      clearEventFields();
      _showSuccessSnackBar('Event added successfully');
    } catch (e) {
      _showErrorSnackBar('Error saving event: $e');
    }
  }

  void _showAddEventDialog(DateTime date) {
    _eventTitle = null;
    _eventDateTime = date;
    _eventDescription = null;
    _eventEndDateTime = null;
    _eventRecurringPattern = null;
    _eventTags = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Event for ${DateFormat('MMM d').format(date)}'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
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
                  // Date picker for the event start date
                  TextButton(
                    onPressed: () async {
                      // Check if the selected date is in the past
                      if (date.isBefore(DateTime.now())) {
                        _showErrorSnackBar(
                            'You cannot create events in the past.');
                        return;
                      }

                      final pickedStartDateTime = await showDateTimePicker(
                        context: context,
                        initialDateTime:
                            _eventDateTime!.add(const Duration(hours: 1)),
                        firstDate:
                            DateTime.now(), // Prevent selection of past dates
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedStartDateTime != null) {
                        setState(() {
                          _eventDateTime = pickedStartDateTime;
                        });
                      }
                    },
                    child:
                        Text(DateFormat('MMM d, yyyy').format(_eventDateTime!)),
                  ),
                  // Date picker for the event end date
                  TextButton(
                    onPressed: () async {
                      if (_eventDateTime == null) {
                        _showErrorSnackBar('Please select a start date first.');
                        return;
                      }

                      final pickedEndDateTime = await showDatePicker(
                        context: context,
                        initialDate:
                            _eventDateTime!.add(const Duration(hours: 1)),
                        firstDate:
                            _eventDateTime!, // Prevent selection of dates before start date
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedEndDateTime != null) {
                        setState(() {
                          _eventEndDateTime = pickedEndDateTime;
                        });
                      }
                    },
                    child: _eventEndDateTime != null
                        ? Text(DateFormat('MMM d, yyyy')
                            .format(_eventEndDateTime!))
                        : const Text('Select End Date (optional)'),
                  ),
                  // Priority dropdown
                  DropdownButton<String>(
                    value: _eventPriority,
                    hint: const Text('Select Priority'),
                    onChanged: (value) {
                      setState(() {
                        _eventPriority = value;
                      });
                    },
                    items: ['high', 'medium', 'low'].map((priority) {
                      return DropdownMenuItem<String>(
                        value: priority,
                        child: Text(priority.toUpperCase()),
                      );
                    }).toList(),
                  ),
                  // Recurring checkbox
                  CheckboxListTile(
                    title: const Text('Recurring Event'),
                    value: _eventIsRecurring ?? false,
                    onChanged: (value) {
                      setState(() {
                        _eventIsRecurring = value;
                      });
                    },
                  ),
                  if (_eventIsRecurring ?? false)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Recurring Pattern (optional)',
                      ),
                      onChanged: (value) {
                        _eventRecurringPattern = value;
                      },
                    ),
                  // Tags input
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tags (optional)',
                    ),
                    onChanged: (value) {
                      _eventTags = value;
                    },
                  ),
                ],
              ),
            );
          },
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

  Future<DateTime?> showDateTimePicker({
    required BuildContext context,
    required DateTime initialDateTime,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: firstDate,
      lastDate: lastDate,
    ).then((date) {
      if (date != null) {
        return showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDateTime),
        ).then((time) {
          if (time != null) {
            return DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          }
          return null;
        });
      }
      return null;
    });
  }

  Widget _buildCalendarGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final date = _getDateForIndex(index);
        final events = _getEventsForDate(date);
        final isToday = _isToday(date);
        final isSelectedMonth = date.month == _selectedDate.month;
        final isSelected = date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;

        // Adjusted isPastDate logic to ignore time
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final isPastDate = date.isBefore(today);

        return GestureDetector(
          onTap: () {
            // Only allow tapping on future or current dates
            if (isPastDate) {
              return; // Do nothing if the date is in the past
            }

            setState(() {
              _selectedDate = date;
            });
            if (events.isEmpty) {
              _showAddEventDialog(
                  date); // Show event dialog if no events are present
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              // Updated background color logic
              color: isPastDate
                  ? Colors.grey
                      .withOpacity(0.3) // Dimming the background for past dates
                  : (isToday
                      ? Colors.blue.withOpacity(0.1)
                      : (isSelectedMonth ? Colors.white : Colors.grey[100])),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelectedMonth
                          ? (isPastDate
                              ? Colors.grey
                              : Colors
                                  .black) // Disable text color for past dates
                          : Colors.grey,
                      fontWeight: isToday
                          ? FontWeight.bold
                          : (isPastDate ? FontWeight.normal : FontWeight.bold),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (events.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        if (index >= 3) {
                          if (index == 3) {
                            return Center(
                              child: Text(
                                '+${events.length - 3}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        return _buildEventIndicator(events[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventIndicator(CalendarEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      height: 12,
      decoration: BoxDecoration(
        color: TaskPriorityColors.getColor(event.priority).withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Tooltip(
        message: '${event.title} (${event.priority})',
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildEventList() {
    final todayEvents = _calendarEvents.where((event) {
      return event.dateTime.year == _selectedDate.year &&
          event.dateTime.month == _selectedDate.month &&
          event.dateTime.day == _selectedDate.day;
    }).toList();

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Events for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: todayEvents.isEmpty
                ? Center(
                    child: Text(
                      'No events for ${DateFormat('MMM d').format(_selectedDate)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: todayEvents.length,
                    itemBuilder: (context, index) {
                      final event = todayEvents[index];
                      return Dismissible(
                        key: ValueKey(event.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteCalendarEvent(event),
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  TaskPriorityColors.getColor(event.priority),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Display start time - If it is not an all-day event
                              Text(
                                (event.dateTime.hour == 0 &&
                                        event.dateTime.minute == 0)
                                    ? DateFormat('MMM d, yyyy').format(event
                                        .dateTime) // Display just the date for all-day events
                                    : DateFormat('h:mm a').format(event
                                        .dateTime), // Display time if it's a specific time
                              ),

                              // Display end time only if it exists (avoid showing "12:00 AM")
                              if (event.endDateTime != null)
                                Text(
                                  DateFormat('h:mm a')
                                      .format(event.endDateTime!),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),

                              // Display description only if it exists
                              if (event.description != null)
                                Text(
                                  event.description!,
                                  style: TextStyle(color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: event.endDateTime != null
                              ? Text(
                                  DateFormat('h:mm a')
                                      .format(event.endDateTime!),
                                  style: TextStyle(color: Colors.grey[600]),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
}
