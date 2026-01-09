import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // --- 1. DEFINE ROUTINES DATA ---
  // Matches the structure of the image you shared (Title, Description, Calories)
  final List<Map<String, dynamic>> _routines = [
    {
      'title': 'Push Workout',
      'desc': 'Bench Press, Shoulder Press, Tricep Dips, Push Ups',
      'calories': 250,
      'duration': '45 mins',
      'icon': FontAwesomeIcons.handFist,
    },
    {
      'title': 'Pull Workout',
      'desc': 'Pull Ups, Bent Over Rows, Bicep Curls, Face Pulls',
      'calories': 230,
      'duration': '45 mins',
      'icon': FontAwesomeIcons.dumbbell,
    },
    {
      'title': 'Legs Workout',
      'desc': 'Squats, Lunges, RDLs, Calf Raises, Leg Press',
      'calories': 350,
      'duration': '50 mins',
      'icon': FontAwesomeIcons.personRunning,
    },
    {
      'title': 'Outdoor Running',
      'desc': '5km run at a moderate pace (approx 6:00/km)',
      'calories': 400,
      'duration': '30 mins',
      'icon': FontAwesomeIcons.road,
    },
    {
      'title': 'Brisk Walking',
      'desc': 'Power walking in the park or treadmill incline',
      'calories': 150,
      'duration': '30 mins',
      'icon': FontAwesomeIcons.personWalking,
    },
  ];

  // --- 2. FUNCTION: LOG ROUTINE TO FIREBASE ---
  void _logWorkout(String title, int calories) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Logging workout to database..."),
        duration: Duration(milliseconds: 800),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calorie_logs')
          .add({
        'title': title,
        'calories': calories,
        'type': 'workout', // Makes it green/blue in the history
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Success Message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text("Logged $title! (-$calories kcal)"),
              ],
            ),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Workout Routines", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.history, color: Colors.black)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _routines.length,
        itemBuilder: (context, index) {
          final routine = _routines[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CARD HEADER (Icon & Title) ---
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(routine['icon'], color: Colors.deepPurple, size: 24),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine['title'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              routine['desc'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // METADATA TAGS
                            Row(
                              children: [
                                _buildTag(Icons.timer_outlined, routine['duration']),
                                const SizedBox(width: 10),
                                _buildTag(Icons.local_fire_department, "${routine['calories']} kcal"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- START BUTTON (Full Width) ---
                GestureDetector(
                  onTap: () => _logWorkout(routine['title'], routine['calories']),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple, // Matches your theme
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Start Routine",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for the small grey tags (Time / Calories)
  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}