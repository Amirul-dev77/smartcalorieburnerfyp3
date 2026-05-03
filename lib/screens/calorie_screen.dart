import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../utils/calculator_logic.dart';

class CalorieScreen extends StatelessWidget {
  const CalorieScreen({super.key});

  // Helper method to display the correct badge based on user goal
  String getGoalText(int goal) {
    if (goal == 0) return "🔥 Deficit (Fat Loss)";
    if (goal == 2) return "💪 Surplus (Muscle)";
    return "⚖️ Maintenance";
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch the user data from your updated provider
    final userProvider = Provider.of<UserProvider>(context);

    // 2. Calculate BMR and TDEE on the fly to show to the user
    double bmr = CalculatorLogic.calculateBMR(
        gender: userProvider.gender,
        weight: userProvider.weight,
        height: userProvider.height,
        age: userProvider.age
    );

    // Calculate TDEE using the BMR and their Activity Level
    double tdee = CalculatorLogic.calculateTDEE(bmr, userProvider.activityLevel);

    // Get today's formatted date
    String todayDate = DateFormat.yMMMd().format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Calorie Tracker", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Today", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(todayDate, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 20),

            // --- The Upgraded Dynamic Purple Card ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D50BB).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title and Goal Chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                          "Calories Remaining",
                          style: TextStyle(color: Colors.white70, fontSize: 14)
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          getGoalText(userProvider.goal),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Middle Row: Big Number and Fire Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${userProvider.calculatedDailyGoal}", // Using your dynamic getter here
                        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(color: Colors.white38),
                  const SizedBox(height: 8),

                  // --- NEW: Bottom Row showing TDEE, BMR, and Target ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Maintenance (TDEE): ${tdee.round()} kcal",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                          const SizedBox(height: 4),
                          Text(
                              "Base BMR: ${bmr.round()} kcal",
                              style: const TextStyle(color: Colors.white70, fontSize: 11) // Faded & smaller
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0), // Aligns nicely with the TDEE text
                        child: Text(
                            "Target: ${userProvider.calculatedDailyGoal} kcal",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- Action Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.keyboard, "Type", Colors.orange),
                _buildActionButton(Icons.barcode_reader, "Scan", Colors.blue),
                _buildActionButton(Icons.menu_book, "Diary", Colors.purple),
              ],
            ),
            const SizedBox(height: 30),

            // --- Recent Entries Section ---
            const Text("Recent Entries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Center(
              child: Text("No entries yet today!", style: TextStyle(color: Colors.grey.shade500)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Helper widget for the three white buttons
  Widget _buildActionButton(IconData icon, String label, Color iconColor) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5)
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}