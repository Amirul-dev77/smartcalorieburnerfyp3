import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'active_workout_screen.dart'; // Make sure this matches your file name!

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // --- 1. DEFINE ROUTINES DATA (With Lifestyle Tags & Hypertrophy Focus) ---
  final List<Map<String, dynamic>> _routines = [
    {
      'title': 'Push Workout',
      'desc': 'Bench Press, Shoulder Press, Lateral Raises, Tricep Dips',
      'calories': 250,
      'duration': '45 mins',
      'icon': FontAwesomeIcons.handFist,
      'lifestyle': ['Moderate', 'Active', 'Very Active'],
    },
    {
      'title': 'Pull Workout',
      'desc': 'Plate-Loaded Rows, Lat Pulldowns, Face Pulls, Bayesian Curls',
      'calories': 230,
      'duration': '45 mins',
      'icon': FontAwesomeIcons.dumbbell,
      'lifestyle': ['Moderate', 'Active', 'Very Active'],
    },
    {
      'title': 'Legs Workout',
      'desc': 'Squats, Leg Press, RDLs, Calf Raises',
      'calories': 350,
      'duration': '50 mins',
      'icon': FontAwesomeIcons.personRunning,
      'lifestyle': ['Moderate', 'Active', 'Very Active'],
    },
    {
      'title': 'Outdoor Running',
      'desc': '5km run at a moderate pace (approx 6:00/km)',
      'calories': 400,
      'duration': '30 mins',
      'icon': FontAwesomeIcons.road,
      'lifestyle': ['Active', 'Very Active'],
    },
    {
      'title': 'Brisk Walking',
      'desc': 'Power walking in the park or treadmill incline',
      'calories': 150,
      'duration': '30 mins',
      'icon': FontAwesomeIcons.personWalking,
      'lifestyle': ['Sedentary', 'Light', 'Moderate'],
    },
    {
      'title': 'Light Stretching',
      'desc': 'Full body mobility and static stretching',
      'calories': 80,
      'duration': '15 mins',
      'icon': FontAwesomeIcons.personPraying,
      'lifestyle': ['Sedentary', 'Light'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    // --- 2. GET LIFESTYLE AND SORT ROUTINES ---
    final userProvider = Provider.of<UserProvider>(context);
    final userLifestyle = userProvider.activityLevel;

    // Create a copy of the list and sort it so "Recommended" items jump to the top
    List<Map<String, dynamic>> sortedRoutines = List.from(_routines);
    sortedRoutines.sort((a, b) {
      bool aIsRecommended = (a['lifestyle'] as List).contains(userLifestyle);
      bool bIsRecommended = (b['lifestyle'] as List).contains(userLifestyle);

      if (aIsRecommended && !bIsRecommended) return -1; // 'a' goes up
      if (!aIsRecommended && bIsRecommended) return 1;  // 'b' goes up
      return 0; // Keep same order
    });

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
            child: Text(
              "Your Level: $userLifestyle",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sortedRoutines.length,
              itemBuilder: (context, index) {
                final routine = sortedRoutines[index];

                // Check if this specific routine matches the user's lifestyle
                bool isRecommended = (routine['lifestyle'] as List).contains(userLifestyle);

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isRecommended ? Border.all(color: Colors.deepPurpleAccent, width: 2) : null,
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
                      // --- RECOMMENDED BADGE ---
                      if (isRecommended)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurpleAccent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text(
                                "Recommended for You",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

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

                      // --- 3. START BUTTON (Navigates to Active Workout Screen) ---
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveWorkoutScreen(routine: routine),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: isRecommended ? Colors.deepPurple : Colors.grey[800],
                            borderRadius: BorderRadius.only(
                              bottomLeft: const Radius.circular(18),
                              bottomRight: const Radius.circular(18),
                              topLeft: isRecommended ? Radius.zero : const Radius.circular(0),
                              topRight: isRecommended ? Radius.zero : const Radius.circular(0),
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
          ),
        ],
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