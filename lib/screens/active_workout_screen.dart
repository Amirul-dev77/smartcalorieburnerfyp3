import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// --- DATA MODELS ---
class WorkoutSetData {
  TextEditingController weightController;
  TextEditingController repsController;
  bool isCompleted;

  WorkoutSetData({String weight = '', String reps = ''})
      : weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        isCompleted = false;

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class ExerciseData {
  String name;
  List<WorkoutSetData> sets;
  int targetRestSeconds;

  ValueNotifier<int> currentRestSeconds;
  Timer? restTimer;

  ExerciseData({required this.name, this.targetRestSeconds = 120})
      : sets = [],
        currentRestSeconds = ValueNotifier<int>(0);

  void dispose() {
    for (var s in sets) {
      s.dispose();
    }
    restTimer?.cancel();
    currentRestSeconds.dispose();
  }
}

// --- MAIN SCREEN ---
class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> routine;

  const ActiveWorkoutScreen({super.key, required this.routine});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  // Global Timers & Stats
  late Timer _globalTimer;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, int>> _workoutStats = ValueNotifier({'volume': 0, 'sets': 0});

  List<ExerciseData> _exercises = [];

  @override
  void initState() {
    super.initState();

    // 1. Parse the exercises from the routine description
    String description = widget.routine['desc'] as String;
    List<String> exerciseNames = description.split(',').map((e) => e.trim()).toList();

    // 2. Initialize the data structure (3 empty sets per exercise)
    for (String name in exerciseNames) {
      ExerciseData ex = ExerciseData(name: name, targetRestSeconds: 120); // Default 2 min rest
      ex.sets = [
        WorkoutSetData(weight: '20', reps: '10'), // Placeholder starting data
        WorkoutSetData(weight: '20', reps: '10'),
        WorkoutSetData(weight: '20', reps: '8'),
      ];
      _exercises.add(ex);
    }

    // 3. Start Global Stopwatch
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds.value++;
    });

    // 4. Calculate initial stats
    _calculateGlobalStats();
  }

  @override
  void dispose() {
    _globalTimer.cancel();
    _elapsedSeconds.dispose();
    _workoutStats.dispose();
    for (var ex in _exercises) {
      ex.dispose();
    }
    super.dispose();
  }

  // --- LOGIC FUNCTIONS ---

  // Formats seconds into MM:SS
  String _formatTime(int totalSeconds) {
    int minutes = (totalSeconds / 60).truncate();
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // Recalculates the Volume and Sets shown in the top header
  void _calculateGlobalStats() {
    int totalVolume = 0;
    int totalSets = 0;

    for (var ex in _exercises) {
      for (var set in ex.sets) {
        if (set.isCompleted) {
          totalSets++;
          int weight = int.tryParse(set.weightController.text) ?? 0;
          int reps = int.tryParse(set.repsController.text) ?? 0;
          totalVolume += (weight * reps);
        }
      }
    }
    _workoutStats.value = {'volume': totalVolume, 'sets': totalSets};
  }

  // Starts the auto-rest timer for a specific exercise
  void _startRestTimer(ExerciseData ex) {
    ex.restTimer?.cancel();
    ex.currentRestSeconds.value = ex.targetRestSeconds;

    ex.restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (ex.currentRestSeconds.value > 0) {
        ex.currentRestSeconds.value--;
      } else {
        timer.cancel();
      }
    });
  }

  // NEW: Adjustable Rest Timer using Minutes and Seconds
  void _editRestTime(ExerciseData ex) {
    int currentMins = ex.targetRestSeconds ~/ 60;
    int currentSecs = ex.targetRestSeconds % 60;

    TextEditingController minCtrl = TextEditingController(text: currentMins.toString());
    TextEditingController secCtrl = TextEditingController(text: currentSecs.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Rest Timer"),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(labelText: "Min", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(":", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextField(
                controller: secCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(labelText: "Sec", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              int mins = int.tryParse(minCtrl.text) ?? 0;
              int secs = int.tryParse(secCtrl.text) ?? 0;
              int totalSeconds = (mins * 60) + secs;

              if (totalSeconds > 0) {
                setState(() => ex.targetRestSeconds = totalSeconds);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  // Logs the workout to Firebase
  void _finishWorkout() async {
    if (_workoutStats.value['sets'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete at least one set!"), backgroundColor: Colors.orange));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('calorie_logs').add({
        'title': widget.routine['title'],
        'calories': widget.routine['calories'],
        'type': 'workout',
        'duration_seconds': _elapsedSeconds.value,
        'volume_kg': _workoutStats.value['volume'],
        'sets_completed': _workoutStats.value['sets'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Go back to Workout List
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Workout Logged! Volume: ${_workoutStats.value['volume']} kg"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.routine['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text("Finish", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- GLOBAL HEADER ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat("DURATION", ValueListenableBuilder<int>(
                  valueListenable: _elapsedSeconds,
                  builder: (context, val, child) => Text(_formatTime(val), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )),
                _buildHeaderStat("VOLUME", ValueListenableBuilder<Map<String, int>>(
                  valueListenable: _workoutStats,
                  builder: (context, stats, child) => Text("${stats['volume']} kg", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )),
                _buildHeaderStat("SETS", ValueListenableBuilder<Map<String, int>>(
                  valueListenable: _workoutStats,
                  builder: (context, stats, child) => Text("${stats['sets']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- EXERCISE LIST ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final ex = _exercises[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exercise Title & Timer Adjust Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ex.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            IconButton(
                              icon: const Icon(Icons.timer_outlined, color: Colors.grey),
                              onPressed: () => _editRestTime(ex),
                              tooltip: "Adjust Rest Timer",
                            )
                          ],
                        ),

                        // Active Rest Timer Display
                        ValueListenableBuilder<int>(
                          valueListenable: ex.currentRestSeconds,
                          builder: (context, remainingSecs, child) {
                            if (remainingSecs == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text("Resting: ${_formatTime(remainingSecs)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),

                        // Table Headers
                        Row(
                          children: [
                            const SizedBox(width: 40, child: Text("SET", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            const Expanded(child: Text("PREVIOUS", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 60, child: Text("KG", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 60, child: Text("REPS", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 40, child: Icon(Icons.check, size: 16, color: Colors.grey)),
                          ],
                        ),
                        const Divider(),

                        // Sets List
                        ...List.generate(ex.sets.length, (setIndex) {
                          final set = ex.sets[setIndex];
                          return Container(
                            color: set.isCompleted ? Colors.green.withOpacity(0.05) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: Text("${setIndex + 1}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text("-", style: TextStyle(color: Colors.grey[400]))),

                                // Weight Input
                                SizedBox(
                                  width: 60,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                    child: TextField(
                                      controller: set.weightController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: set.isCompleted ? Colors.grey : Colors.black),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                                      onChanged: (val) => _calculateGlobalStats(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Reps Input
                                SizedBox(
                                  width: 60,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                    child: TextField(
                                      controller: set.repsController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: set.isCompleted ? Colors.grey : Colors.black),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                                      onChanged: (val) => _calculateGlobalStats(),
                                    ),
                                  ),
                                ),

                                // Completion Checkbox
                                SizedBox(
                                  width: 40,
                                  child: Checkbox(
                                    value: set.isCompleted,
                                    activeColor: Colors.green,
                                    onChanged: (val) {
                                      setState(() {
                                        set.isCompleted = val ?? false;
                                        _calculateGlobalStats();
                                      });
                                      if (set.isCompleted) {
                                        FocusScope.of(context).unfocus();
                                        _startRestTimer(ex);
                                      }
                                    },
                                  ),
                                )
                              ],
                            ),
                          );
                        }),

                        // Add Set Button
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              ex.sets.add(WorkoutSetData(weight: '20', reps: '10'));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add Set"),
                          style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // Helper widget for the top bar
  Widget _buildHeaderStat(String label, Widget child) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}