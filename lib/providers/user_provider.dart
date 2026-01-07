import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class UserProvider with ChangeNotifier {
  // --- DATA VARIABLES ---
  String name = "Loading...";
  String email = "";
  String gender = "male";
  String activityLevel = "Moderate";

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

  // --- NEW: CATEGORY LOGIC ---
  String get bmiCategory {
    if (_bmi <= 0) return "Calculate First";
    if (_bmi < 18.5) return "Underweight";
    if (_bmi < 25.0) return "Normal";
    if (_bmi < 30.0) return "Overweight";
    return "Obese";
  }

  String get bodyFatCategory {
    if (_bodyFat <= 0) return "-";

    // Logic varies by gender
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

  // Helper to get color for the category (Green = Good, Red = Bad)
  Color get statusColor {
    if (bmiCategory == "Normal" || bmiCategory == "Fitness" || bmiCategory == "Athlete") {
      return Colors.greenAccent;
    } else if (bmiCategory == "Underweight" || bmiCategory == "Average") {
      return Colors.yellowAccent;
    } else {
      return Colors.orangeAccent; // Overweight/Obese
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

        height = (data['height'] ?? 0).toDouble();
        weight = (data['weight'] ?? 0).toDouble();
        neck = (data['neck'] ?? 0).toDouble();
        hip = (data['hip'] ?? 0).toDouble();

        // Check Gender to pick correct waist field
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
  }) {
    weight = w;
    height = h;
    neck = n;
    waist = waistVal;
    hip = hipVal;

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