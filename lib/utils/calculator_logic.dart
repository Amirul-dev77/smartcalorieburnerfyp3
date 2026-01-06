import 'dart:math';

class CalculatorLogic {

  // Helper for Log10
  static double log10(num x) => log(x) / ln10;

  // BMI Calculation [cite: 25]
  // Weight in Kg, Height in cm (converted to meters)
  static double calculateBMI(double weightKg, double heightCm) {
    double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  // US Navy Method Body Fat Calculation [cite: 31, 34]
  static double calculateBodyFat({
    required String gender,
    required double heightCm,
    required double neckCm,
    required double waistCm, // Represents Abdomen for men [cite: 17]
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
}