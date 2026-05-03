import 'dart:math';

class CalculatorLogic {

  // Helper for Log10
  static double log10(num x) => log(x) / ln10;

  // BMI Calculation
  // Weight in Kg, Height in cm (converted to meters)
  static double calculateBMI(double weightKg, double heightCm) {
    double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  // US Navy Method Body Fat Calculation
  static double calculateBodyFat({
    required String gender,
    required double heightCm,
    required double neckCm,
    required double waistCm, // Represents Abdomen for men
    required double hipCm,
  }) {
    if (gender.toLowerCase() == 'male') {
      // Formula: 86.010 * log10(abdomen - neck) - 70.041 * log10(height) + 36.76
      return (86.010 * log10(waistCm - neckCm)) -
          (70.041 * log10(heightCm)) + 36.76;
    } else {
      // Formula: 163.205 * log10(waist + hip - neck) - 97.684 * log10(height) - 78.387
      return (163.205 * log10(waistCm + hipCm - neckCm)) -
          (97.684 * log10(heightCm)) - 78.387;
    }
  }

  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 24.9) return "Normal";
    if (bmi < 29.9) return "Overweight";
    return "Obese";
  }

  // Extended Lifestyle Determination Logic
  static String determineLifestyleExtended({
    required int workStyle,     // 0: Sitting, 1: Mixed, 2: Active
    required int exerciseDays,  // 0 to 7
    required int dailyMovement, // 0: Minimal, 1: Moderate, 2: High
  }) {
    // Note: Goals and Time Availability don't change the TDEE multiplier,
    // but they are gathered for customizing the user's future workout plans.
    int score = (workStyle * 2) + exerciseDays + dailyMovement;

    if (score <= 2) return 'Sedentary';
    if (score <= 5) return 'Light';
    if (score <= 8) return 'Moderate';
    if (score <= 11) return 'Active';
    return 'Very Active';
  }
}