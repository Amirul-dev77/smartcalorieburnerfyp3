import 'dart:math';

class CalculatorLogic {

  // Helper for Log10
  static double log10(num x) => log(x) / ln10;

  // --- BMI & BODY FAT ---

  static double calculateBMI(double weightKg, double heightCm) {
    double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 24.9) return "Normal";
    if (bmi < 29.9) return "Overweight";
    return "Obese";
  }

  static double calculateBodyFat({
    required String gender,
    required double heightCm,
    required double neckCm,
    required double waistCm,
    required double hipCm,
  }) {
    if (gender.toLowerCase() == 'male') {
      return (86.010 * log10(waistCm - neckCm)) - (70.041 * log10(heightCm)) + 36.76;
    } else {
      return (163.205 * log10(waistCm + hipCm - neckCm)) - (97.684 * log10(heightCm)) - 78.387;
    }
  }

  // --- LIFESTYLE SCORING ---

  static String determineLifestyleExtended({
    required int workStyle,     // 0: Sitting, 1: Mixed, 2: Active
    required int exerciseDays,  // 0 to 7
    required int dailyMovement, // 0: Minimal, 1: Moderate, 2: High
  }) {
    int score = (workStyle * 2) + exerciseDays + dailyMovement;

    if (score <= 2) return 'Sedentary';
    if (score <= 5) return 'Light';
    if (score <= 8) return 'Moderate';
    if (score <= 11) return 'Active';
    return 'Very Active';
  }

  // --- CALORIE TARGET LOGIC ---

  // 1. Calculate BMR using Mifflin-St Jeor equation
  static double calculateBMR({required String gender, required double weight, required double height, required int age}) {
    if (gender.toLowerCase() == 'male') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  // 2. Calculate TDEE based on Activity Level multiplier
  static double calculateTDEE(double bmr, String activityLevel) {
    switch (activityLevel) {
      case 'Sedentary': return bmr * 1.2;
      case 'Light': return bmr * 1.375;
      case 'Moderate': return bmr * 1.55;
      case 'Active': return bmr * 1.725;
      case 'Very Active': return bmr * 1.9;
      default: return bmr * 1.2;
    }
  }

  // 3. Apply the Goal Modifier to get the Target Calories
  static double calculateTargetCalories(double tdee, int goal) {
    // 0: Lose Fat (-500 kcal)
    // 1: Maintain (0 kcal)
    // 2: Build Muscle (+300 kcal)
    if (goal == 0) return tdee - 500;
    if (goal == 2) return tdee + 300;
    return tdee;
  }
}