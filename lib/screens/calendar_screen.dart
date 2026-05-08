import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'workout_screen.dart'; // To navigate to the workout screen

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  Map<DateTime, List<Map<String, dynamic>>> _workoutHistory = {};
  bool _isLoading = true;
  int _monthlyWorkoutCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutHistory();
  }

  // --- 1. FETCH ALL WORKOUTS FROM FIREBASE ---
  Future<void> _fetchWorkoutHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calorie_logs')
          .get();

      Map<DateTime, List<Map<String, dynamic>>> fetchedData = {};
      int currentMonthCount = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (data['type'] != 'food') {
          if (data['timestamp'] != null) {
            DateTime dt = (data['timestamp'] as Timestamp).toDate();
            DateTime normalizedDate = DateTime(dt.year, dt.month, dt.day);

            if (fetchedData[normalizedDate] == null) {
              fetchedData[normalizedDate] = [];
            }
            fetchedData[normalizedDate]!.add(data);

            if (dt.month == _focusedDay.month && dt.year == _focusedDay.year) {
              currentMonthCount++;
            }
          }
        }
      }

      setState(() {
        _workoutHistory = fetchedData;
        _monthlyWorkoutCount = currentMonthCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching calendar data: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    DateTime normalized = DateTime(day.year, day.month, day.day);
    return _workoutHistory[normalized] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> selectedDayWorkouts = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Workout Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
      // 👉 FIX: Wrapped the entire layout in a SingleChildScrollView
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- HEVY-STYLE MONTHLY STATS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge("🔥", "$_monthlyWorkoutCount Workouts", "This Month"),
                  Container(height: 40, width: 1, color: Colors.grey.shade300),
                  _buildStatBadge("💪", "Active", "Status"),
                ],
              ),
            ),

            // --- THE CUSTOM CALENDAR ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _monthlyWorkoutCount = _workoutHistory.keys
                        .where((k) => k.month == focusedDay.month && k.year == focusedDay.year)
                        .length;
                  });
                },
                eventLoader: _getEventsForDay,

                // 👉 BONUS FIX: Hides the default overlapping dots!
                calendarStyle: const CalendarStyle(
                  markersMaxCount: 0,
                ),

                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                ),
                rowHeight: 70,

                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isSelected: false),
                  selectedBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isSelected: true),
                  todayBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isSelected: false, isToday: true),
                  outsideBuilder: (context, day, focusedDay) => _buildCalendarDay(day, isSelected: false, isOutside: true),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- SELECTED DAY ACTIVITY LIST ---
            // 👉 FIX: Removed "Expanded" so it scrolls with the whole page
            Container(
              width: double.infinity,
              // Added bottom padding so the list doesn't get hidden behind the Floating Action Button
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 100),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDay != null ? "Activity for ${DateFormat.MMMd().format(_selectedDay!)}" : "Activity",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  selectedDayWorkouts.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 50, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text("No workout logged.", style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  )
                  // 👉 FIX: Added shrinkWrap & NeverScrollableScrollPhysics
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedDayWorkouts.length,
                    itemBuilder: (context, index) {
                      var workout = selectedDayWorkouts[index];
                      return _buildWorkoutLogCard(workout);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutScreen()));
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ==========================================
  // --- UI HELPER WIDGETS ---
  // ==========================================

  Widget _buildCalendarDay(DateTime day, {bool isSelected = false, bool isToday = false, bool isOutside = false}) {
    List<Map<String, dynamic>> events = _getEventsForDay(day);
    bool hasWorkout = events.isNotEmpty;

    String workoutName = hasWorkout
        ? (events.length > 1 ? "Multiple" : (events.first['title'] ?? 'Workout'))
        : '';

    return Container(
      margin: const EdgeInsets.only(top: 5.0),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange
                  : (hasWorkout ? Colors.blueAccent : Colors.transparent),
              shape: BoxShape.circle,
              border: isToday && !isSelected ? Border.all(color: Colors.deepPurple, width: 2) : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isOutside
                      ? Colors.grey.shade400
                      : (isSelected || hasWorkout ? Colors.white : Colors.black),
                  fontWeight: (isSelected || hasWorkout || isToday) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          if (hasWorkout && !isOutside)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                workoutName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.orange : Colors.blueAccent,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String emoji, String title, String subtitle) {
    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildWorkoutLogCard(Map<String, dynamic> workout) {
    String title = workout['title'] ?? 'Unknown Workout';
    int calories = workout['calories'] ?? 0;
    int volume = workout['volume_kg'] ?? 0;
    String type = workout['type'] ?? 'manual_exercise';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF8F9FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: (type == 'cardio' ? Colors.green : Colors.deepPurple).withOpacity(0.1),
              shape: BoxShape.circle
          ),
          child: Icon(
              type == 'cardio' ? Icons.directions_run : Icons.fitness_center,
              color: type == 'cardio' ? Colors.green : Colors.deepPurple
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(volume > 0 ? "Volume: $volume kg" : "Cardio Activity", style: const TextStyle(color: Colors.black54)),
        trailing: Text("$calories kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}