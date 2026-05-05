import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import 'workout_screen.dart'; // IMPORTANT: Import the workout screen!

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime selectedDate = DateTime.now();

  void _changeDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
  }

  void _showAddMealDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController calController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Meal"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name (e.g., Apple)")),
            TextField(controller: calController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Calories")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && calController.text.isNotEmpty) {
                Provider.of<UserProvider>(context, listen: false).addMeal(
                    nameController.text,
                    int.parse(calController.text)
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    int remaining = userProvider.remainingCalories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Daily Diary", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeDate(-1)),
                Text(
                  DateFormat.yMMMd().format(selectedDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeDate(1)),
              ],
            ),
            const SizedBox(height: 20),

            // --- 1. TOP SUMMARY CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Text("Calories Remaining", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    "$remaining",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: remaining < 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMathColumn("Goal", "${userProvider.calculatedDailyGoal}", Colors.black87),
                      const Text("-", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      _buildMathColumn("Food", "${userProvider.totalFoodConsumed}", Colors.orange),
                      const Text("+", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      _buildMathColumn("Exercise", "${userProvider.totalExerciseBurned}", Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- 2. HORIZONTALLY SCROLLABLE REPORT CARDS ---
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildReportCard(
                    title: "Daily Calories",
                    subtitle: "vs. Target",
                    child: _buildMockBarChart(
                      value: userProvider.totalFoodConsumed.toDouble(),
                      target: userProvider.calculatedDailyGoal.toDouble(),
                      color: Colors.orange,
                    ),
                  ),
                  _buildReportCard(
                    title: "Net Calories",
                    subtitle: "Consumed - Burned",
                    child: Center(
                      child: Text(
                        "${userProvider.totalFoodConsumed - userProvider.totalExerciseBurned} kcal",
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: (userProvider.totalFoodConsumed - userProvider.totalExerciseBurned) <= userProvider.calculatedDailyGoal ? Colors.green : Colors.red
                        ),
                      ),
                    ),
                  ),
                  _buildReportCard(
                    title: "Workout Volume",
                    subtitle: "Today's Total Lifted",
                    child: _buildDynamicVolumeCard(userProvider.totalWorkoutVolume),
                  ),
                  _buildReportCard(
                    title: "Combined Activity",
                    subtitle: "Food vs Burned",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildSingleBar(userProvider.totalFoodConsumed.toDouble() / 20, Colors.orange, "Eaten"),
                        const SizedBox(width: 20),
                        _buildSingleBar(userProvider.totalExerciseBurned.toDouble() / 20, Colors.purple, "Burned"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 3. MEALS LIST ---
            _buildSectionHeader("Meals", "${userProvider.totalFoodConsumed} kcal", _showAddMealDialog),
            if (userProvider.todayMeals.isEmpty) const Text("No meals logged yet.", style: TextStyle(color: Colors.grey)),
            ...userProvider.todayMeals.map((meal) => _buildLogCard(Icons.restaurant, meal.title, meal.subtitle, "${meal.calories} kcal", Colors.orange)).toList(),

            const SizedBox(height: 30),

            // --- 4. EXERCISE LIST ---
            // THE NEW NAVIGATION: Pushes directly to the Active Workout Screen!
            _buildSectionHeader("Exercise", "${userProvider.totalExerciseBurned} kcal", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WorkoutScreen()),
              );
            }),
            if (userProvider.todayExercises.isEmpty) const Text("No exercises logged yet.", style: TextStyle(color: Colors.grey)),
            ...userProvider.todayExercises.map((ex) => _buildLogCard(Icons.fitness_center, ex.title, ex.subtitle, "${ex.calories} kcal (Vol: ${ex.volume}kg)", Colors.purple)).toList(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildMathColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String totalKcal, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: onAdd),
            ],
          ),
          Text(totalKcal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLogCard(IconData icon, String title, String subtitle, String trailing, Color iconColor) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildReportCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 15, bottom: 5, top: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 15),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildMockBarChart({required double value, required double target, required Color color}) {
    double fillPercentage = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 40,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
        ),
        FractionallySizedBox(
          heightFactor: fillPercentage,
          child: Container(
            width: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          ),
        ),
        Positioned(
          bottom: 80,
          child: Container(height: 2, width: 60, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildSingleBar(double height, Color color, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: height.clamp(0.0, 80.0),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDynamicVolumeCard(int totalVolume) {
    if (totalVolume == 0) {
      return const Center(
        child: Text("No volume logged today.", style: TextStyle(color: Colors.grey)),
      );
    }
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, color: Colors.blue, size: 40),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "$totalVolume",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.blue)
              ),
              const Text("kg lifted", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}