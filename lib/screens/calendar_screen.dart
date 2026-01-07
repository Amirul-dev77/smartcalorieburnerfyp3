import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Calendar State
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final List<String> _workoutOptions = [
    "Weightlifting (Push day)",
    "Weightlifting (Pull day)",
    "Weightlifting (Leg day)",
    "Cardio (Walking)",
    "Cardio (Running)",
    "Rest Day"
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // --- 1. ADD WORKOUT DIALOG ---
  void _showAddWorkoutDialog() {
    String selectedType = _workoutOptions[0];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log Workout"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date: ${DateFormat('MMM dd, yyyy').format(_selectedDay)}"),
                const SizedBox(height: 15),
                const Text("Select Activity:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedType,
                  items: _workoutOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedType = val!;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                // Save to 'calendar' collection
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('calendar')
                    .add({
                  'date': Timestamp.fromDate(_selectedDay),
                  'date_string': DateFormat('yyyy-MM-dd').format(_selectedDay),
                  'type': selectedType,
                  'created_at': FieldValue.serverTimestamp(),
                });
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // --- 2. EDIT WORKOUT DIALOG (NEW FUNCTION) ---
  void _showEditWorkoutDialog(String docId, String currentType) {
    // Ensure the current type exists in the list, otherwise default to the first option
    String selectedType = _workoutOptions.contains(currentType)
        ? currentType
        : _workoutOptions[0];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Workout"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Change Activity:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedType,
                  items: _workoutOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedType = val!;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                // Update the existing document
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('calendar')
                    .doc(docId)
                    .update({
                  'type': selectedType, // Update the 'type' field
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Workout updated successfully!")),
                  );
                }
              }
            },
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- 3. DELETE WORKOUT ---
  Future<void> _deleteWorkout(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('calendar')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Workout deleted")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final String queryDate = DateFormat('yyyy-MM-dd').format(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Calendar"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkoutDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [

          // --- CALENDAR WIDGET ---
          StreamBuilder<QuerySnapshot>(
              stream: uid == null
                  ? const Stream.empty()
                  : FirebaseFirestore.instance.collection('users').doc(uid).collection('calendar').snapshots(),
              builder: (context, snapshot) {

                Map<String, List<dynamic>> eventsMap = {};

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dateStr = data['date_string'] as String?;
                    if (dateStr != null) {
                      if (eventsMap[dateStr] == null) {
                        eventsMap[dateStr] = [];
                      }
                      eventsMap[dateStr]!.add(data);
                    }
                  }
                }

                return Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2023, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,

                    eventLoader: (day) {
                      final key = DateFormat('yyyy-MM-dd').format(day);
                      return eventsMap[key] ?? [];
                    },

                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                      markerDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                    ),

                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),

                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = _normalizeDate(selectedDay);
                        _focusedDay = focusedDay;
                      });
                    },
                  ),
                );
              }
          ),

          // --- WORKOUT LIST SECTION ---
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Activity for ${DateFormat('MMM dd').format(_selectedDay)}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: uid == null
                        ? const Center(child: Text("Please log in"))
                        : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('calendar')
                          .where('date_string', isEqualTo: queryDate)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fitness_center, size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text("No workout logged.", style: TextStyle(color: Colors.grey[400])),
                              ],
                            ),
                          );
                        }

                        final workouts = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: workouts.length,
                          itemBuilder: (context, index) {
                            final data = workouts[index].data() as Map<String, dynamic>;
                            final type = data['type'] ?? "Unknown";
                            final docId = workouts[index].id;

                            IconData icon = Icons.fitness_center;
                            Color color = Colors.deepPurple;
                            if (type.contains("Cardio")) {
                              icon = Icons.directions_run;
                              color = Colors.orange;
                            } else if (type.contains("Leg")) {
                              icon = Icons.accessibility_new;
                              color = Colors.blue;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.2),
                                  child: Icon(icon, color: color),
                                ),
                                title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),

                                // --- MODIFIED TRAILING SECTION ---
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min, // Vital: Keeps buttons together
                                  children: [
                                    // 1. EDIT BUTTON
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        // Open the new Edit Dialog
                                        _showEditWorkoutDialog(docId, type);
                                      },
                                    ),
                                    // 2. DELETE BUTTON
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _deleteWorkout(docId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}