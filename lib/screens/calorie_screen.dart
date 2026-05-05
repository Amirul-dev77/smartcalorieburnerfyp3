import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../providers/user_provider.dart';
import '../utils/calculator_logic.dart';
import 'diary_screen.dart';

class CalorieScreen extends StatefulWidget {
  const CalorieScreen({super.key});

  @override
  State<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends State<CalorieScreen> {

  // --- API 1: CALORIE NINJA ---
  Future<void> _searchFoodWithCalorieNinja(String foodQuery) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    const String apiKey = 'Xo5aaPKG8n+yWPPyj2L9Yw==yGp3Ve3SBX9084js'; // 👉 PASTE YOUR KEY HERE
    final url = Uri.parse('https://api.calorieninjas.com/v1/nutrition?query=$foodQuery');

    try {
      final response = await http.get(url, headers: {'X-Api-Key': apiKey});
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          final foodItem = data['items'][0];
          _showResultDialog(foodItem['name'].toString().toUpperCase(), foodItem['calories'].round(), true);
        } else {
          _showError("Food not found. Try another search!");
        }
      } else {
        _showError("API Error: ${response.statusCode}");
      }
    } catch (e) {
      Navigator.pop(context);
      _showError("Network Error. Check your connection.");
    }
  }

  // --- API 2: OPEN FOOD FACTS ---
  Future<void> _scanBarcodeWithFoodFacts() async {
    try {
      String? barcodeScanRes = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
      );

      if (barcodeScanRes == null || barcodeScanRes == '-1') return;

      debugPrint("🔍 SCANNED BARCODE: $barcodeScanRes");
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcodeScanRes.json');
      final response = await http.get(url);

      Navigator.pop(context);
      debugPrint("🔍 API STATUS CODE: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          String productName = product['product_name'] ?? "Unknown Product";

          var nutriments = product['nutriments'];
          if (nutriments != null) {
            dynamic energyKcal = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal_serving'] ?? nutriments['energy-kcal'] ?? 0;

            if (energyKcal == 0) {
              _showError("Found '$productName', but no calorie data is listed!");
            } else {
              _showResultDialog(productName, (energyKcal as num).round(), true);
            }
          } else {
            _showError("Found '$productName', but nutrition facts are empty!");
          }
        } else {
          _showError("Product not found in the global database.");
        }
      } else {
        _showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔍 SCAN CRASH ERROR: $e");
      _showError("Failed to scan. Error: $e");
    }
  }

  // --- UI HELPER DIALOGS ---
  void _showTypeFoodDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("What did you eat?"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g., 2 boiled eggs and 1 apple"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) _searchFoodWithCalorieNinja(controller.text);
            },
            child: const Text("Search"),
          )
        ],
      ),
    );
  }

  void _showResultDialog(String name, int calories, bool isFood) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Found It!"),
        content: Text("Name: $name\nCalories: $calories kcal", style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Discard")),
          ElevatedButton(
            onPressed: () async {
              // 👉 THE MAGIC LINK: Pushes API result straight to Firebase!
              if (isFood) {
                await Provider.of<UserProvider>(context, listen: false).saveMealToFirebase(name, calories);
              } else {
                await Provider.of<UserProvider>(context, listen: false).saveExerciseToFirebase(name, calories, 0);
              }
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $calories kcal to Diary!"), backgroundColor: Colors.green));
            },
            child: const Text("Add to Diary"),
          )
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  String getGoalText(int goal) {
    if (goal == 0) return "🔥 Deficit (Fat Loss)";
    if (goal == 2) return "💪 Surplus (Muscle)";
    return "⚖️ Maintenance";
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    double bmr = CalculatorLogic.calculateBMR(gender: userProvider.gender, weight: userProvider.weight, height: userProvider.height, age: userProvider.age);
    double tdee = CalculatorLogic.calculateTDEE(bmr, userProvider.activityLevel);
    String todayDate = DateFormat.yMMMd().format(DateTime.now());

    List<LogEntry> recentEntries = [...userProvider.todayMeals, ...userProvider.todayExercises];
    recentEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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

            // --- Purple Dashboard Card ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF9D50BB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Calories Remaining", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(getGoalText(userProvider.goal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${userProvider.remainingCalories}", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white38, height: 1),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildStatColumn("Base BMR", "${bmr.round()} kcal", CrossAxisAlignment.start)),
                      Container(width: 1, height: 30, color: Colors.white38),
                      Expanded(child: _buildStatColumn("TDEE", "${tdee.round()} kcal", CrossAxisAlignment.center)),
                      Container(width: 1, height: 30, color: Colors.white38),
                      Expanded(child: _buildStatColumn("Target", "${userProvider.calculatedDailyGoal} kcal", CrossAxisAlignment.end)),
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
                _buildActionButton(Icons.keyboard, "Type", Colors.orange, _showTypeFoodDialog),
                _buildActionButton(Icons.qr_code_scanner, "Scan", Colors.blue, _scanBarcodeWithFoodFacts),
                _buildActionButton(Icons.menu_book, "Diary", Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DiaryScreen()));
                }),
              ],
            ),
            const SizedBox(height: 30),

            // --- RECENT ENTRIES ---
            const Text("Recent Entries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: recentEntries.isEmpty
                  ? Center(child: Text("No entries yet today!", style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                itemCount: recentEntries.length > 4 ? 4 : recentEntries.length,
                itemBuilder: (context, index) {
                  final entry = recentEntries[index];
                  bool isWorkout = entry.title == "Workout";
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (isWorkout ? Colors.purple : Colors.orange).withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(isWorkout ? Icons.fitness_center : Icons.restaurant, color: isWorkout ? Colors.purple : Colors.orange),
                      ),
                      title: Text(entry.subtitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text("${entry.calories} kcal", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}