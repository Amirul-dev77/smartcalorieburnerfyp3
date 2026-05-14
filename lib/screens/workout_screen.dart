import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👉 NEW
import '../providers/user_provider.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // --- 1. YOUR HARDCODED ROUTINES (These will ALWAYS exist) ---
  final List<Map<String, dynamic>> _defaultRoutines = [
    {
      'title': 'Push Workout', 'type': 'strength', 'calories': 250, 'duration': '45 mins', 'icon': FontAwesomeIcons.handFist,
      'desc': 'Bench Press, Shoulder Press, Lateral Raises, Tricep Dips',
      'lifestyle': ['Moderate', 'Active', 'Very Active'], 'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
    },
    {
      'title': 'Pull Workout', 'type': 'strength', 'calories': 230, 'duration': '45 mins', 'icon': FontAwesomeIcons.dumbbell,
      'desc': 'Plate-Loaded Rows, Lat Pulldowns, Face Pulls, Bayesian Curls',
      'lifestyle': ['Moderate', 'Active', 'Very Active'], 'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
    },
    {
      'title': 'Legs Workout', 'type': 'strength', 'calories': 350, 'duration': '50 mins', 'icon': FontAwesomeIcons.personRunning,
      'desc': 'Squats, Leg Press, RDLs, Calf Raises',
      'lifestyle': ['Moderate', 'Active', 'Very Active'], 'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
    },
    {
      'title': 'Outdoor Running', 'type': 'cardio', 'calories': 400, 'duration': '30 mins', 'icon': FontAwesomeIcons.road,
      'desc': '5km run at a moderate pace (approx 6:00/km)',
      'lifestyle': ['Active', 'Very Active'], 'bmi': ['Normal', 'Underweight'],
    },
    {
      'title': 'Brisk Walking', 'type': 'cardio', 'calories': 150, 'duration': '30 mins', 'icon': FontAwesomeIcons.personWalking,
      'desc': 'Power walking in the park or treadmill incline',
      'lifestyle': ['Sedentary', 'Light', 'Moderate'], 'bmi': ['Overweight', 'Obese', 'Normal', 'Underweight'],
    },
  ];

  // Helper to give Firebase routines a cool icon
  IconData _getIconForType(String title, String type) {
    String t = title.toLowerCase();
    if (t.contains('push')) return FontAwesomeIcons.handFist;
    if (t.contains('pull') || t.contains('strength')) return FontAwesomeIcons.dumbbell;
    if (t.contains('leg')) return FontAwesomeIcons.personRunning;
    if (t.contains('run')) return FontAwesomeIcons.road;
    if (t.contains('walk')) return FontAwesomeIcons.personWalking;
    if (t.contains('stretch') || t.contains('yoga')) return FontAwesomeIcons.personPraying;
    if (type == 'cardio') return FontAwesomeIcons.heartPulse;
    return FontAwesomeIcons.dumbbell;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userLifestyle = userProvider.activityLevel;
    final double userBmi = userProvider.bmi;

    String bmiCategory;
    if (userBmi < 18.5) bmiCategory = 'Underweight';
    else if (userBmi < 24.9) bmiCategory = 'Normal';
    else if (userBmi < 29.9) bmiCategory = 'Overweight';
    else bmiCategory = 'Obese';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Summary Header (Untouched)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
            color: Colors.white,
            child: Wrap(
              spacing: 10,
              children: [
                Chip(label: Text("Level: $userLifestyle", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), backgroundColor: Colors.deepPurple.withOpacity(0.1), side: BorderSide.none),
                Chip(label: Text("BMI: $bmiCategory", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), backgroundColor: Colors.blue.withOpacity(0.1), side: BorderSide.none),
              ],
            ),
          ),

          // 👉 NEW: StreamBuilder merges Default list with Firebase list!
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('routines').snapshots(),
              builder: (context, snapshot) {
                // 1. Start with the guaranteed default list
                List<Map<String, dynamic>> combinedRoutines = List.from(_defaultRoutines);

                // 2. If admin added new ones to Firebase, grab them and merge!
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  List<Map<String, dynamic>> firebaseRoutines = snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['icon'] = _getIconForType(data['title'] ?? '', data['type'] ?? '');
                    return data;
                  }).toList();
                  combinedRoutines.addAll(firebaseRoutines);
                }

                // 3. Run YOUR exact Smart Sorting Algorithm on the combined list
                combinedRoutines.sort((a, b) {
                  int scoreA = 0; int scoreB = 0;
                  if ((a['lifestyle'] as List? ?? []).contains(userLifestyle)) scoreA++;
                  if ((a['bmi'] as List? ?? []).contains(bmiCategory)) scoreA++;
                  if ((b['lifestyle'] as List? ?? []).contains(userLifestyle)) scoreB++;
                  if ((b['bmi'] as List? ?? []).contains(bmiCategory)) scoreB++;
                  return scoreB.compareTo(scoreA);
                });

                // 4. Render YOUR exact UI layout
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: combinedRoutines.length,
                  itemBuilder: (context, index) {
                    final routine = combinedRoutines[index];

                    int matchScore = 0;
                    if ((routine['lifestyle'] as List? ?? []).contains(userLifestyle)) matchScore++;
                    if ((routine['bmi'] as List? ?? []).contains(bmiCategory)) matchScore++;

                    bool isPerfectMatch = matchScore == 2;
                    bool isGoodMatch = matchScore == 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isPerfectMatch ? Border.all(color: Colors.deepPurpleAccent, width: 2) : (isGoodMatch ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1) : null),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPerfectMatch)
                            Container(
                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: const BoxDecoration(color: Colors.deepPurpleAccent, borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
                              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star, color: Colors.white, size: 14), SizedBox(width: 5), Text("Perfect Match", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                            )
                          else if (isGoodMatch)
                            Container(
                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.thumb_up, color: Colors.blue[700], size: 14), const SizedBox(width: 5), Text("Good Fit", style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold))]),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: isPerfectMatch ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(routine['icon'], color: isPerfectMatch ? Colors.deepPurple : Colors.grey[700], size: 24),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(routine['title'] ?? 'Workout', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 5),
                                      Text(routine['desc'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          _buildTag(Icons.timer_outlined, routine['duration']?.toString() ?? 'N/A'),
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

                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(routine: routine)));
                            },
                            child: Container(
                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: isPerfectMatch ? Colors.deepPurple : (isGoodMatch ? Colors.blue[600] : Colors.grey[800]),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: const Radius.circular(18), bottomRight: const Radius.circular(18),
                                  topLeft: (isPerfectMatch || isGoodMatch) ? Radius.zero : const Radius.circular(18),
                                  topRight: (isPerfectMatch || isGoodMatch) ? Radius.zero : const Radius.circular(18),
                                ),
                              ),
                              child: const Center(child: Text("Start Routine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: Colors.grey[600]), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600))],
      ),
    );
  }
}