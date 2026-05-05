import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

// --- DATA MODEL FOR DIARY ENTRIES ---
class LogEntry {
  final String title;
  final String subtitle;
  final int calories;
  final int volume;
  final DateTime timestamp;

  LogEntry({
    required this.title,
    required this.subtitle,
    required this.calories,
    this.volume = 0,
    required this.timestamp
  });
}

class UserProvider with ChangeNotifier {
  // --- DATA VARIABLES ---
  String name = "Loading...";
  String email = "";
  String gender = "male";
  String activityLevel = "Moderate";

  int goal = 1;
  int age = 25;
  double height = 0;
  double weight = 0;
  double neck = 0;
  double waist = 0;
  double hip = 0;

  double _bmi = 0;
  double _bodyFat = 0;

  double get bmi => _bmi;
  double get bodyFat => _bodyFat;

  // --- DIARY STATE MANAGEMENT ---
  List<LogEntry> todayMeals = [];
  List<LogEntry> todayExercises = [];

  int get totalFoodConsumed => todayMeals.fold(0, (sum, item) => sum + item.calories);
  int get totalExerciseBurned => todayExercises.fold(0, (sum, item) => sum + item.calories);
  int get totalWorkoutVolume => todayExercises.fold(0, (sum, item) => sum + item.volume);
  int get remainingCalories => calculatedDailyGoal - totalFoodConsumed + totalExerciseBurned;

  // --- LOCAL ONLY ADDS (Used by ActiveWorkoutScreen to prevent double-saving) ---
  void addMeal(String name, int calories) {
    todayMeals.insert(0, LogEntry(title: "Food", subtitle: name, calories: calories, timestamp: DateTime.now()));
    notifyListeners();
  }

  void addExercise(String name, int calories, int volume) {
    todayExercises.insert(0, LogEntry(title: "Workout", subtitle: name, calories: calories, volume: volume, timestamp: DateTime.now()));
    notifyListeners();
  }

  // ==========================================
  // --- NEW: FIREBASE SYNC METHODS ---
  // ==========================================

  // 1. Fetch Today's Data on App Load
  Future<void> fetchTodayLogs() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calorie_logs')
          .where('timestamp', isGreaterThanOrEqualTo: startOfToday)
          .orderBy('timestamp', descending: true)
          .get();

      todayMeals.clear();
      todayExercises.clear();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String type = data['type'] ?? '';
        String title = data['title'] ?? 'Unknown';
        int calories = (data['calories'] ?? 0).toInt();
        int volume = (data['volume_kg'] ?? 0).toInt();

        DateTime time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();

        if (type == 'food') {
          todayMeals.add(LogEntry(title: "Food", subtitle: title, calories: calories, timestamp: time));
        } else {
          todayExercises.add(LogEntry(title: "Workout", subtitle: title, calories: calories, volume: volume, timestamp: time));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching today's logs: $e");
    }
  }

  // 2. Save Manual Meal to Firebase
  Future<void> saveMealToFirebase(String name, int calories) async {
    addMeal(name, calories); // Update UI instantly so it feels fast

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('calorie_logs').add({
        'title': name,
        'calories': calories,
        'type': 'food',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // 3. Save Manual Exercise to Firebase
  Future<void> saveExerciseToFirebase(String name, int calories, int volume) async {
    addExercise(name, calories, volume); // Update UI instantly

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('calorie_logs').add({
        'title': name,
        'calories': calories,
        'volume_kg': volume,
        'type': 'manual_exercise',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- DYNAMIC DAILY CALORIE GOAL ---
  int get calculatedDailyGoal {
    if (height == 0 || weight == 0) return 2200;
    double bmr = (gender.toLowerCase() == 'male')
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    double multiplier;
    switch (activityLevel) {
      case 'Sedentary': multiplier = 1.2; break;
      case 'Light': multiplier = 1.375; break;
      case 'Moderate': multiplier = 1.55; break;
      case 'Active': multiplier = 1.725; break;
      case 'Very Active': multiplier = 1.9; break;
      default: multiplier = 1.55;
    }

    int tdee = (bmr * multiplier).round();
    int targetCalorie = (goal == 0) ? tdee - 500 : (goal == 2) ? tdee + 300 : tdee;

    if (gender.toLowerCase() == 'female' && targetCalorie < 1200) return 1200;
    if (gender.toLowerCase() == 'male' && targetCalorie < 1500) return 1500;
    return targetCalorie;
  }

  // --- FETCH USER PROFILE ---
  Future<void> fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        name = data['name'] ?? "User";
        email = data['email'] ?? "";
        gender = data['gender'] ?? "male";
        activityLevel = data['activityLevel'] ?? "Moderate";
        goal = data['goal'] ?? 1;
        age = data['age'] ?? 25;
        height = (data['height'] ?? 0).toDouble();
        weight = (data['weight'] ?? 0).toDouble();
        neck = (data['neck'] ?? 0).toDouble();
        hip = (data['hip'] ?? 0).toDouble();
        waist = (gender.toLowerCase() == 'male')
            ? (data['abdomen'] ?? data['waist'] ?? 0).toDouble()
            : (data['waist'] ?? data['abdomen'] ?? 0).toDouble();

        calculateMetrics();
        notifyListeners();

        // 👉 THE FIX: FETCH DIARY LOGS AFTER PROFILE LOADS
        await fetchTodayLogs();
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  void updateProfile({required double w, required double h, required double n, required double waistVal, double hipVal = 0, int userAge = 25}) {
    weight = w; height = h; neck = n; waist = waistVal; hip = hipVal; age = userAge;
    calculateMetrics();
    notifyListeners();
  }

  void calculateMetrics() {
    if (height > 0 && weight > 0) _bmi = weight / ((height / 100) * (height / 100)); else _bmi = 0;
    if (height > 0 && waist > 0 && neck > 0) {
      if (gender.toLowerCase() == 'male') {
        if (waist - neck > 0) _bodyFat = 495 / (1.0324 - 0.19077 * (log(waist - neck) / ln10) + 0.15456 * (log(height) / ln10)) - 450; else _bodyFat = 0;
      } else {
        if (hip > 0 && (waist + hip - neck) > 0) _bodyFat = 495 / (1.29579 - 0.35004 * (log(waist + hip - neck) / ln10) + 0.22100 * (log(height) / ln10)) - 450; else _bodyFat = 0;
      }
    } else _bodyFat = 0;
    if (_bodyFat > 0) { if (_bodyFat < 2) _bodyFat = 2; if (_bodyFat > 70) _bodyFat = 70; }
  }

  String get bmiCategory {
    if (_bmi <= 0) return "Calculate First";
    if (_bmi < 18.5) return "Underweight";
    if (_bmi < 25.0) return "Normal";
    if (_bmi < 30.0) return "Overweight";
    return "Obese";
  }

  String get bodyFatCategory {
    if (_bodyFat <= 0) return "-";
    if (gender.toLowerCase() == 'male') {
      if (_bodyFat < 6) return "Essential Fat"; if (_bodyFat < 14) return "Athlete"; if (_bodyFat < 18) return "Fitness"; if (_bodyFat < 25) return "Average"; return "Obese";
    } else {
      if (_bodyFat < 14) return "Essential Fat"; if (_bodyFat < 21) return "Athlete"; if (_bodyFat < 25) return "Fitness"; if (_bodyFat < 32) return "Average"; return "Obese";
    }
  }

  Color get statusColor {
    if (bmiCategory == "Normal" || bmiCategory == "Fitness" || bmiCategory == "Athlete") return Colors.greenAccent;
    if (bmiCategory == "Underweight" || bmiCategory == "Average") return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}