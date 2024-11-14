import 'package:flutter/material.dart';
import 'package:zen_assist/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zen_assist/screens/feedbackmain.dart';
import 'package:zen_assist/screens/inboxscreen.dart';

void main() {
  runApp(Adminhomepage());
}

class Adminhomepage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTimeFrame = '7 days ago';
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  DateTime? sessionStartTime;

  @override
  void initState() {
    super.initState();
    _logAppOpenEvent();
    _startSession();
  }

  @override
  void dispose() {
    _logAppCloseEvent();
    _endSession();
    super.dispose();
  }

  void _logAppOpenEvent() async {
    await analytics.logEvent(
      name: 'app_open',
      parameters: {'screen': 'dashboard_screen'},
    );
  }

  void _logAppCloseEvent() async {
    await analytics.logEvent(
      name: 'app_close',
      parameters: {'screen': 'dashboard_screen'},
    );
  }

  void _startSession() {
    sessionStartTime = DateTime.now();
  }

  Future<void> _endSession() async {
    if (sessionStartTime != null) {
      DateTime endTime = DateTime.now();
      await FirebaseFirestore.instance.collection('sessions').add({
        'startTime': sessionStartTime,
        'endTime': endTime,
      });
    }
  }

  Future<double> calculateAverageSessionTime() async {
    QuerySnapshot sessionsSnapshot =
        await FirebaseFirestore.instance.collection('sessions').get();

    if (sessionsSnapshot.docs.isEmpty) return 0;

    double totalDuration = 0;
    int sessionCount = sessionsSnapshot.docs.length;

    for (var session in sessionsSnapshot.docs) {
      DateTime? startTime = (session['startTime'] as Timestamp?)?.toDate();
      DateTime? endTime = (session['endTime'] as Timestamp?)?.toDate();

      if (startTime != null && endTime != null) {
        double duration = endTime.difference(startTime).inSeconds.toDouble();
        totalDuration += duration;
      }
    }

    return totalDuration / sessionCount;
  }

  Future<Map<int, double>> calculateHourlyAverageSessionTime() async {
    QuerySnapshot sessionsSnapshot =
        await FirebaseFirestore.instance.collection('sessions').get();

    if (sessionsSnapshot.docs.isEmpty) return {};

    Map<int, List<double>> sessionDurationsByHour = {};

    for (var session in sessionsSnapshot.docs) {
      DateTime? startTime = (session['startTime'] as Timestamp?)?.toDate();
      DateTime? endTime = (session['endTime'] as Timestamp?)?.toDate();

      if (startTime != null && endTime != null) {
        int hour = startTime.hour;
        double duration = endTime.difference(startTime).inSeconds.toDouble();

        if (!sessionDurationsByHour.containsKey(hour)) {
          sessionDurationsByHour[hour] = [];
        }
        sessionDurationsByHour[hour]!.add(duration);
      }
    }

    // Calculate average for each hour
    Map<int, double> averageSessionTimeByHour = {
      10: 120.0, // 10:00 AM - 2 minutes
      11: 180.0, // 11:00 AM - 3 minutes
      13: 240.0, // 1:00 PM - 4 minutes
      15: 300.0, // 3:00 PM - 5 minutes
    };
    sessionDurationsByHour.forEach((hour, durations) {
      double totalDuration = durations.reduce((a, b) => a + b);
      averageSessionTimeByHour[hour] = totalDuration / durations.length;
    });

    return averageSessionTimeByHour;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ZenAssistApp()),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 153, 201, 180),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: AssetImage('assets/images/profile.jpg'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Welcome Back,',
                    style: TextStyle(
                      fontSize: 16, // Reduced font size
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Angelina Leanore',
                    style: TextStyle(
                      fontSize: 18, // Reduced font size
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text('Inbox'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminInboxScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Feedbacks'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FeedbackApp()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Admin Dashboard"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Ensures the entire screen is scrollable
          child: Center(
            child: Container(
              width:
                  double.infinity, // Makes sure the container takes full width
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeframe Dropdown and Stats Grid
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<String>(
                          value: _selectedTimeFrame,
                          items: <String>[
                            '1 day ago',
                            '3 days ago',
                            '7 days ago',
                            '1 month ago',
                            '3 months ago',
                            '1 year ago',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedTimeFrame = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stat Cards with Overflow Fixes
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true, // Ensures GridView shrinks to fit content
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 15,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Average Time Spent Per Session
                      FutureBuilder<double>(
                        future: calculateAverageSessionTime(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildStatCard(
                              context,
                              'Avg Time/Session',
                              'Calculating...',
                              'Please wait...',
                              Colors.green[200]!,
                              Icons.timer,
                            );
                          }
                          if (snapshot.hasError) {
                            return _buildStatCard(
                              context,
                              'Avg Time/Session',
                              'Error',
                              'Unable to calculate',
                              Colors.green[200]!,
                              Icons.timer,
                            );
                          }

                          double averageDuration = snapshot.data ?? 0;
                          String formattedTime =
                              Duration(seconds: averageDuration.toInt())
                                  .toString()
                                  .split('.')
                                  .first; // Format duration as HH:MM:SS
                          return _buildStatCard(
                            context,
                            'Avg Time/Session',
                            formattedTime,
                            'Calculated for sessions',
                            Colors.green[200]!,
                            Icons.timer,
                          );
                        },
                      ),
                      // Task Completion
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('stats')
                            .doc('taskCompletion')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildStatCard(
                              context,
                              'Task Completion',
                              'Loading...',
                              'Counting...',
                              Colors.blue[200]!,
                              Icons.check_circle,
                            );
                          }

                          if (snapshot.hasError) {
                            return _buildStatCard(
                              context,
                              'Task Completion',
                              'Error',
                              'Unable to load data',
                              Colors.blue[200]!,
                              Icons.check_circle,
                            );
                          }

                          int completionCount =
                              snapshot.data?.data()?['count'] ?? 0;

                          return _buildStatCard(
                            context,
                            'Task Completion',
                            '$completionCount',
                            'Completed tasks',
                            Colors.blue[200]!,
                            Icons.check_circle,
                          );
                        },
                      ),
                      // Feature Utilization
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('stats')
                            .doc('featureUtilization')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildStatCard(
                              context,
                              'Feature Utilization',
                              'Loading...',
                              'Calculating...',
                              Colors.red[200]!,
                              Icons.settings,
                            );
                          }

                          if (snapshot.hasError) {
                            return _buildStatCard(
                              context,
                              'Feature Utilization',
                              'Error',
                              'Unable to load data',
                              Colors.red[200]!,
                              Icons.settings,
                            );
                          }

                          Map<String, dynamic> featureData =
                              snapshot.data?.data() ?? {};
                          int totalUtilization = featureData.values
                              .fold(0, (sum, value) => sum + (value as int));

                          return _buildStatCard(
                            context,
                            'Feature Utilization',
                            '$totalUtilization',
                            'Total feature use',
                            Colors.red[200]!,
                            Icons.settings,
                          );
                        },
                      ),
                      // Total Users
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildStatCard(
                              context,
                              'Total Users',
                              'Loading...',
                              'Counting users...',
                              Colors.purple[200]!,
                              Icons.person,
                            );
                          }

                          if (snapshot.hasError) {
                            return _buildStatCard(
                              context,
                              'Total Users',
                              'Error',
                              'Unable to load data',
                              Colors.purple[200]!,
                              Icons.person,
                            );
                          }

                          int totalUserCount = snapshot.data?.docs.length ?? 0;

                          return _buildStatCard(
                            context,
                            'Total Users',
                            '$totalUserCount',
                            'Total registered users',
                            Colors.purple[200]!,
                            Icons.person,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'INTERACTION',
                    style: TextStyle(
                      fontSize: 16, // Reduced font size
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Text(
                    'User Engagement',
                    style: TextStyle(
                      fontSize: 18, // Reduced font size
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Adjust the size of the bar chart container
                  Container(
                    width:
                        double.infinity, // Ensures it takes up the full width
                    height: MediaQuery.of(context).size.height *
                        0.35, // Adjust height dynamically
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: FutureBuilder<Map<int, double>>(
                        future: calculateHourlyAverageSessionTime(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.red),
                            );
                          }

                          Map<int, double> hourlyData = snapshot.data ?? {};
                          List<BarChartGroupData> barGroups =
                              hourlyData.entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value /
                                      60, // Convert seconds to minutes
                                  width: 30,
                                  borderRadius: BorderRadius.circular(2),
                                  color: Colors.blue,
                                ),
                              ],
                            );
                          }).toList();

                          return BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: hourlyData.values.isNotEmpty
                                  ? (hourlyData.values
                                              .reduce((a, b) => a > b ? a : b) /
                                          60) +
                                      5
                                  : 10,
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 50,
                                    getTitlesWidget: (value, meta) {
                                      return Text('${value.toInt()} mins');
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text('${value.toInt()}:00');
                                    },
                                  ),
                                ),
                              ),
                              barGroups: barGroups,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String count,
    String subtitle,
    Color color,
    IconData icon, {
    double titleFontSize = 10,
    double countFontSize = 18,
    double subtitleFontSize = 8,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count,
                style: TextStyle(
                    fontSize: countFontSize, fontWeight: FontWeight.bold),
              ),
              Icon(icon, size: 40),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                TextStyle(fontSize: subtitleFontSize, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
