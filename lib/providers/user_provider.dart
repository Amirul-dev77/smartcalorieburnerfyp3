import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

// --- DATA MODEL FOR DIARY ENTRIES ---
class LogEntry {
  final String title;
  final String subtitle;
  final int calories;
  final int volume; // Tracks weight lifted (kg)
  final DateTime timestamp;

  LogEntry({
    required this.title,
    required this.subtitle,
    required this.calories,
    this.volume = 0, // Default to 0 for food or cardio
    required this.timestamp
  });
}

class UserProvider with ChangeNotifier {
  // --- DATA VARIABLES ---
  String name = "Loading...";
  String email = "";
  String gender = "male";
  String activityLevel = "Moderate";

  int goal = 1;      // 0: Fat Loss, 1: Maintain, 2: Muscle
  int age = 25;
  double height = 0; // cm
  double weight = 0; // kg
  double neck = 0;   // cm
  double waist = 0;  // cm (Abdomen for men)
  double hip = 0;    // cm (Required for women)

  // --- CALCULATED METRICS ---
  double _bmi = 0;
  double _bodyFat = 0;

  // Getters
  double get bmi => _bmi;
  double get bodyFat => _bodyFat;

  // --- DIARY STATE MANAGEMENT ---
  List<LogEntry> todayMeals = [];
  List<LogEntry> todayExercises = [];

  // Automatically sum up the calories and volume from the lists
  int get totalFoodConsumed => todayMeals.fold(0, (sum, item) => sum + item.calories);
  int get totalExerciseBurned => todayExercises.fold(0, (sum, item) => sum + item.calories);
  int get totalWorkoutVolume => todayExercises.fold(0, (sum, item) => sum + item.volume);

  // Calculate true remaining calories dynamically
  int get remainingCalories => calculatedDailyGoal - totalFoodConsumed + totalExerciseBurned;

  // Methods to add entries from the UI
  void addMeal(String name, int calories) {
    todayMeals.insert(0, LogEntry(
        title: "Food",
        subtitle: name,
        calories: calories,
        timestamp: DateTime.now()
    ));
    notifyListeners();
  }

  void addExercise(String name, int calories, int volume) {
    todayExercises.insert(0, LogEntry(
        title: "Workout",
        subtitle: name,
        calories: calories,
        volume: volume,
        timestamp: DateTime.now()
    ));
    notifyListeners();
  }

  // --- DYNAMIC DAILY CALORIE GOAL (Mifflin-St Jeor) ---
  int get calculatedDailyGoal {
    if (height == 0 || weight == 0) return 2200; // Fallback if data isn't loaded yet

    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

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
    int targetCalorie;

    // Apply the Goal Modifier dynamically
    if (goal == 0) {
      targetCalorie = tdee - 500; // Deficit for Fat Loss
    } else if (goal == 2) {
      targetCalorie = tdee + 300; // Surplus for Building Muscle
    } else {
      targetCalorie = tdee;       // Maintenance
    }

    // Safety floors (Do not drop below healthy minimums)
    if (gender.toLowerCase() == 'female' && targetCalorie < 1200) return 1200;
    if (gender.toLowerCase() == 'male' && targetCalorie < 1500) return 1500;

    return targetCalorie;
  }

  // --- CATEGORY LOGIC ---
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
      if (_bodyFat < 6) return "Essential Fat";
      if (_bodyFat < 14) return "Athlete";
      if (_bodyFat < 18) return "Fitness";
      if (_bodyFat < 25) return "Average";
      return "Obese";
    } else {
      if (_bodyFat < 14) return "Essential Fat";
      if (_bodyFat < 21) return "Athlete";
      if (_bodyFat < 25) return "Fitness";
      if (_bodyFat < 32) return "Average";
      return "Obese";
    }
  }

  Color get statusColor {
    if (bmiCategory == "Normal" || bmiCategory == "Fitness" || bmiCategory == "Athlete") {
      return Colors.greenAccent;
    } else if (bmiCategory == "Underweight" || bmiCategory == "Average") {
      return Colors.yellowAccent;
    } else {
      return Colors.orangeAccent;
    }
  }

  // --- 1. FETCH REAL DATA FROM FIREBASE ---
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

        if (gender.toLowerCase() == 'male') {
          waist = (data['abdomen'] ?? data['waist'] ?? 0).toDouble();
        } else {
          waist = (data['waist'] ?? data['abdomen'] ?? 0).toDouble();
        }

        calculateMetrics();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  // --- 2. UPDATE LOCAL DATA ---
  void updateProfile({
    required double w,
    required double h,
    required double n,
    required double waistVal,
    double hipVal = 0,
    int userAge = 25,
  }) {
    weight = w;
    height = h;
    neck = n;
    waist = waistVal;
    hip = hipVal;
    age = userAge;

    calculateMetrics();
    notifyListeners();
  }

  // --- 3. MATH LOGIC (US Navy Method) ---
  void calculateMetrics() {
    if (height > 0 && weight > 0) {
      _bmi = weight / ((height / 100) * (height / 100));
    } else {
      _bmi = 0;
    }

    if (height > 0 && waist > 0 && neck > 0) {
      if (gender.toLowerCase() == 'male') {
        if (waist - neck > 0) {
          double val = 495 / (1.0324 - 0.19077 * (log(waist - neck) / ln10) + 0.15456 * (log(height) / ln10)) - 450;
          _bodyFat = val;
        } else {
          _bodyFat = 0;
        }
      } else {
        if (hip > 0 && (waist + hip - neck) > 0) {
          double val = 495 / (1.29579 - 0.35004 * (log(waist + hip - neck) / ln10) + 0.22100 * (log(height) / ln10)) - 450;
          _bodyFat = val;
        } else {
          _bodyFat = 0;
        }
      }
    } else {
      _bodyFat = 0;
    }

    if (_bodyFat > 0) {
      if (_bodyFat < 2) _bodyFat = 2;
      if (_bodyFat > 70) _bodyFat = 70;
    }
  }
}