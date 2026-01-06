import 'package:flutter/material.dart';
import '../utils/calculator_logic.dart';

class UserProvider with ChangeNotifier {
  // Profile Data
  String name = "User";
  String gender = "male";
  double height = 175; // cm
  double weight = 70; // kg
  double neck = 40; // cm
  double waist = 85; // cm (Abdomen)
  double hip = 95; // cm
  String activityLevel = "Moderate";

  // Calorie Data
  int calorieGoal = 2500;
  int foodIntake = 0;
  int exerciseBurned = 0;

  // Getters for Calculated Values
  double get bmi => CalculatorLogic.calculateBMI(weight, height);

  double get bodyFat => CalculatorLogic.calculateBodyFat(
    gender: gender,
    heightCm: height,
    neckCm: neck,
    waistCm: waist,
    hipCm: hip,
  );

  int get remainingCalories => calorieGoal - foodIntake + exerciseBurned;

  // Methods to update data
  void updateProfile({required double w, required double h, required double n, required double waistVal}) {
    weight = w;
    height = h;
    neck = n;
    waist = waistVal;
    notifyListeners();
  }

  void addFood(int calories) {
    foodIntake += calories;
    notifyListeners();
  }

  void addExercise(int calories) {
    exerciseBurned += calories;
    notifyListeners();
  }
}