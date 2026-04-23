import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// ==========================================
// 1. DATA MODELS (Strength Training)
// ==========================================
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

// ==========================================
// 2. MAIN SCREEN
// ==========================================
class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic> routine;

  const ActiveWorkoutScreen({super.key, required this.routine});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late bool isCardio;

  // --- GLOBAL STATE (Shared) ---
  Timer? _timer;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);

  // --- STRENGTH STATE ---
  final ValueNotifier<Map<String, int>> _workoutStats = ValueNotifier({'volume': 0, 'sets': 0});
  List<ExerciseData> _exercises = [];

  // --- CARDIO STATE ---
  bool _isCardioRunning = false;
  bool _isCardioFinished = false;
  final TextEditingController _distanceCtrl = TextEditingController();
  final TextEditingController _stepsCtrl = TextEditingController();
  double _calculatedPace = 0.0;
  int _calculatedCalories = 0;

  // SMART GOALS
  int _targetMins = 30;
  double _targetKm = 3.0;

  // --- LIVE SENSOR TRACKING ---
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<StepCount>? _stepStream;
  Position? _lastPosition;
  double _liveDistanceKm = 0.0;
  int _initialSteps = -1; // -1 means we haven't grabbed the starting steps yet

  @override
  void initState() {
    super.initState();
    isCardio = widget.routine['type'] == 'cardio';

    if (isCardio) {
      _calculatedCalories = widget.routine['calories'] ?? 0;
    } else {
      String description = widget.routine['desc'] as String;
      List<String> exerciseNames = description.split(',').map((e) => e.trim()).toList();

      for (String name in exerciseNames) {
        ExerciseData ex = ExerciseData(name: name, targetRestSeconds: 120);
        ex.sets = [
          WorkoutSetData(weight: '20', reps: '10'),
          WorkoutSetData(weight: '20', reps: '10'),
          WorkoutSetData(weight: '20', reps: '8'),
        ];
        _exercises.add(ex);
      }
      _startTimer();
      _calculateGlobalStats();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopLiveTracking(); // Clean up sensor streams to save battery!
    _elapsedSeconds.dispose();
    _workoutStats.dispose();
    for (var ex in _exercises) {
      ex.dispose();
    }
    _distanceCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // 3. SHARED LOGIC
  // ==========================================
  String _formatTime(int totalSeconds) {
    int minutes = (totalSeconds / 60).truncate();
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds.value++;
      if (isCardio) _calculateCardioMetrics();
    });
  }

  // ==========================================
  // 4. LIVE SENSOR LOGIC (NEW!)
  // ==========================================
  Future<void> _startLiveTracking() async {
    // 1. Request OS Permissions
    var locStatus = await Permission.location.request();
    var actStatus = await Permission.activityRecognition.request();

    // 2. Start GPS Tracking
    if (locStatus.isGranted) {
      // Use LocationSettings to only update when they move at least 5 meters (saves battery)
      _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
      ).listen((Position position) {
        if (_lastPosition != null) {
          // Calculate distance between last ping and current ping in meters
          double distanceInMeters = Geolocator.distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude,
          );

          setState(() {
            _liveDistanceKm += (distanceInMeters / 1000); // Convert to km
            _distanceCtrl.text = _liveDistanceKm.toStringAsFixed(2); // Auto-fill the UI box!
          });
        }
        _lastPosition = position;
      });
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS access denied. Distance must be entered manually.")));
    }

    // 3. Start Step Tracking
    if (actStatus.isGranted) {
      _stepStream = Pedometer.stepCountStream.listen((StepCount event) {
        setState(() {
          // The pedometer counts total steps since the phone was turned on.
          // We capture the starting number, and subtract it to get the session steps.
          if (_initialSteps == -1) _initialSteps = event.steps;

          int currentSessionSteps = event.steps - _initialSteps;
          _stepsCtrl.text = currentSessionSteps.toString(); // Auto-fill the UI box!
        });
      });
    }
  }

  void _stopLiveTracking() {
    _positionStream?.cancel();
    _stepStream?.cancel();
  }

  // ==========================================
  // 5. STRENGTH LOGIC
  // ==========================================
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
            Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Min"))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text(":", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            Expanded(child: TextField(controller: secCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Sec"))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              int mins = int.tryParse(minCtrl.text) ?? 0;
              int secs = int.tryParse(secCtrl.text) ?? 0;
              int totalSeconds = (mins * 60) + secs;
              if (totalSeconds > 0) setState(() => ex.targetRestSeconds = totalSeconds);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _finishStrengthWorkout() async {
    if (_workoutStats.value['sets'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete at least one set!"), backgroundColor: Colors.orange));
      return;
    }
    _saveToFirebase({
      'title': widget.routine['title'],
      'calories': widget.routine['calories'],
      'type': 'strength',
      'duration_seconds': _elapsedSeconds.value,
      'volume_kg': _workoutStats.value['volume'],
      'sets_completed': _workoutStats.value['sets'],
    });
  }

  // ==========================================
  // 6. CARDIO LOGIC (Smart Recommendation)
  // ==========================================
  void _calculateCardioMetrics() {
    double distance = double.tryParse(_distanceCtrl.text) ?? 0.0;
    double minutes = _elapsedSeconds.value / 60.0;

    setState(() {
      if (distance > 0) {
        _calculatedPace = minutes / distance;
      } else {
        _calculatedPace = 0.0;
      }
      _calculatedCalories = ((minutes * 5) + (distance * 40)).round();
    });
  }

  void _calculateSmartGoal(double bmi, String lifestyle) {
    int mins = 30;
    double km = 3.0;

    if (bmi >= 30) {
      mins -= 10;
      km -= 1.0;
    } else if (bmi >= 25 || bmi < 18.5) {
      mins -= 5;
      km -= 0.5;
    }

    if (lifestyle == 'Sedentary') {
      mins -= 5;
      km -= 0.5;
    } else if (lifestyle == 'Very Active') {
      mins += 15;
      km += 2.0;
    } else if (lifestyle == 'Active') {
      mins += 5;
      km += 0.5;
    }

    if (mins < 10) mins = 10;
    if (km < 1.0) km = 1.0;

    _targetMins = mins;
    _targetKm = km;
  }

  void _finishCardioWorkout() {
    if (_elapsedSeconds.value < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout too short to log!"), backgroundColor: Colors.orange));
      return;
    }
    _saveToFirebase({
      'title': widget.routine['title'],
      'calories': _calculatedCalories,
      'type': 'cardio',
      'duration_seconds': _elapsedSeconds.value,
      'distance_km': double.tryParse(_distanceCtrl.text) ?? 0.0,
      'pace': _calculatedPace,
      'steps': int.tryParse(_stepsCtrl.text) ?? 0,
      'target_achieved': (_elapsedSeconds.value / 60) >= _targetMins,
    });
  }

  // ==========================================
  // 7. FIREBASE SAVING
  // ==========================================
  void _saveToFirebase(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      data['timestamp'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('calorie_logs').add(data);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Workout Logged successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 8. UI ROUTING
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (isCardio) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _calculateSmartGoal(userProvider.bmi, userProvider.activityLevel);
      return _buildCardioUI();
    } else {
      return _buildStrengthUI();
    }
  }

  // ==========================================
  // 9. CARDIO UI BUILDER
  // ==========================================
  Widget _buildCardioUI() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(widget.routine['title']), centerTitle: true, elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            // --- SMART GOAL BANNER ---
            if (!_isCardioFinished)
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.blue),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Suggested Goal", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("Aim for $_targetMins mins or ${_targetKm.toStringAsFixed(1)} km.", style: TextStyle(color: Colors.blue[900], fontSize: 15)),
                          const SizedBox(height: 8),
                          Text("* The suggestion was made based on your profile.", style: TextStyle(color: Colors.blue[700], fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // --- STOPWATCH ---
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _isCardioRunning ? Colors.deepPurple.withOpacity(0.1) : Colors.white, border: Border.all(color: Colors.deepPurple, width: 4)),
              child: ValueListenableBuilder<int>(
                valueListenable: _elapsedSeconds,
                builder: (context, val, child) => Text(_formatTime(val), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ),
            ),
            const SizedBox(height: 40),

            // --- START/PAUSE/END CONTROLS ---
            if (!_isCardioFinished) ...[
              if (!_isCardioRunning)
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() { _isCardioRunning = true; });
                      _startTimer();
                      _startLiveTracking(); // <-- TURNS ON SENSORS!
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    child: const Text("START WALK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() { _isCardioRunning = false; });
                          _timer?.cancel();
                          _stopLiveTracking(); // <-- PAUSES SENSORS
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Colors.orange, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("PAUSE", style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() { _isCardioRunning = false; _isCardioFinished = true; });
                          _timer?.cancel();
                          _stopLiveTracking(); // <-- STOPS SENSORS
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("END WALK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
            ],

            // --- LIVE DATA DISPLAY (Shows while running AND at the end) ---
            if (_isCardioRunning || _isCardioFinished) ...[
              const SizedBox(height: 30),
              Text(_isCardioFinished ? "Final Details" : "Live Stats", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Notice we still use TextFields! If GPS fails, the user can manually type here at the end.
              TextField(
                controller: _distanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: "Distance (km)", prefixIcon: const Icon(Icons.map), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                onChanged: (val) => _calculateCardioMetrics(),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _stepsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Steps (Optional)", prefixIcon: const Icon(Icons.directions_walk), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text("PACE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("${_calculatedPace.toStringAsFixed(2)} min/km", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text("CALORIES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text("$_calculatedCalories kcal", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ],

            if (_isCardioFinished) ...[
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _finishCardioWorkout,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("LOG CARDIO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 10. STRENGTH UI BUILDER
  // ==========================================
  Widget _buildStrengthUI() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.routine['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        actions: [TextButton(onPressed: _finishStrengthWorkout, child: const Text("Finish", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)))],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat("DURATION", ValueListenableBuilder<int>(valueListenable: _elapsedSeconds, builder: (ctx, val, child) => Text(_formatTime(val), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                _buildHeaderStat("VOLUME", ValueListenableBuilder<Map<String, int>>(valueListenable: _workoutStats, builder: (ctx, stats, child) => Text("${stats['volume']} kg", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                _buildHeaderStat("SETS", ValueListenableBuilder<Map<String, int>>(valueListenable: _workoutStats, builder: (ctx, stats, child) => Text("${stats['sets']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final ex = _exercises[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 20), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(ex.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            ),
                            IconButton(icon: const Icon(Icons.timer_outlined, color: Colors.grey), onPressed: () => _editRestTime(ex))
                          ],
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: ex.currentRestSeconds,
                          builder: (context, remainingSecs, child) {
                            if (remainingSecs == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.timer, size: 16, color: Colors.blue), const SizedBox(width: 8), Text("Resting: ${_formatTime(remainingSecs)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))]),
                            );
                          },
                        ),
                        Row(
                          children: const [
                            SizedBox(width: 40, child: Text("SET", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            Expanded(child: Text("PREVIOUS", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            SizedBox(width: 60, child: Text("KG", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            SizedBox(width: 60, child: Text("REPS", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                            SizedBox(width: 40, child: Icon(Icons.check, size: 16, color: Colors.grey)),
                          ],
                        ),
                        const Divider(),
                        ...List.generate(ex.sets.length, (setIndex) {
                          final set = ex.sets[setIndex];
                          return Container(
                            color: set.isCompleted ? Colors.green.withOpacity(0.05) : Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: Text("${setIndex + 1}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text("-", style: TextStyle(color: Colors.grey[400]))),
                                SizedBox(width: 60, child: Container(decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: set.weightController, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: set.isCompleted ? Colors.grey : Colors.black), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)), onChanged: (val) => _calculateGlobalStats()))),
                                const SizedBox(width: 10),
                                SizedBox(width: 60, child: Container(decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: set.repsController, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: set.isCompleted ? Colors.grey : Colors.black), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)), onChanged: (val) => _calculateGlobalStats()))),
                                SizedBox(width: 40, child: Checkbox(value: set.isCompleted, activeColor: Colors.green, onChanged: (val) { setState(() { set.isCompleted = val ?? false; _calculateGlobalStats(); }); if (set.isCompleted) { FocusScope.of(context).unfocus(); _startRestTimer(ex); }}))
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        TextButton.icon(onPressed: () { setState(() { ex.sets.add(WorkoutSetData(weight: '20', reps: '10')); }); }, icon: const Icon(Icons.add, size: 16), label: const Text("Add Set"), style: TextButton.styleFrom(foregroundColor: Colors.deepPurple))
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

  Widget _buildHeaderStat(String label, Widget child) {
    return Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), child]);
  }
}