import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import 'workout_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime selectedDate = DateTime.now();

  void _changeDate(int days) async {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
    // Fetch historical data for the newly selected date from Firebase
    await Provider.of<UserProvider>(context, listen: false).fetchLogsForDate(selectedDate);
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
            onPressed: () async {
              if (nameController.text.isNotEmpty && calController.text.isNotEmpty) {
                // Saves to Firebase on the currently selected date
                await Provider.of<UserProvider>(context, listen: false).saveMealToFirebase(
                    nameController.text,
                    int.parse(calController.text),
                    selectedDate
                );
                if (mounted) Navigator.pop(context);
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
            // --- Date Navigator ---
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
                  // Graph 1: Daily Calories
                  _buildReportCard(
                    title: "Daily Calories",
                    subtitle: "vs. Target",
                    child: _buildMockBarChart(
                      value: userProvider.totalFoodConsumed.toDouble(),
                      target: userProvider.calculatedDailyGoal.toDouble(),
                      color: Colors.orange,
                    ),
                  ),
                  // Graph 2: Net Calories
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
                  // Graph 3: Workout Volume
                  _buildReportCard(
                    title: "Workout Volume",
                    subtitle: "Today's Total Lifted",
                    child: _buildDynamicVolumeCard(userProvider.totalWorkoutVolume),
                  ),
                  // Graph 4: Combined Activity
                  _buildReportCard(
                    title: "Combined Activity",
                    subtitle: "Food vs Burned",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildSingleBar(userProvider.totalFoodConsumed.toDouble(), Colors.orange, "Eaten"),
                        const SizedBox(width: 20),
                        _buildSingleBar(userProvider.totalExerciseBurned.toDouble(), Colors.purple, "Burned"),
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

  // UPDATED: Original target line placement (80% / 125%) with side-by-side values & EXACT width match
  Widget _buildMockBarChart({required double value, required double target, required Color color}) {
    // Math fix: Grey bar is 125% of target. Red line is at 80% (which equals 100% target).
    double fillPercentage = target > 0 ? (value / target) : 0.0;
    double displayPercentage = (fillPercentage * 0.8).clamp(0.0, 1.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. The Bar Chart
        SizedBox(
          width: 50,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Grey Background (Represents 125% so there is headroom)
              Container(
                width: 35,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              ),
              // Colored Fill (Dynamically scales to hit the red line at 100%)
              FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: displayPercentage,
                child: Container(
                  width: 35,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              // Red Target Line (Anchored perfectly at 80% of the grey bar's height)
              FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.8,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                      height: 3,
                      width: 35, // FIXED: Now exactly matches the 35 width of the grey bar!
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(2))
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. The Numerical Stats Beside the Graph
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${value.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
            const Text("Consumed", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            Text("${target.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
            const Text("Target", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // Accepts the raw value and scales it internally so the exact number can be printed
  Widget _buildSingleBar(double value, Color color, String label) {
    double displayHeight = (value / 20).clamp(0.0, 80.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
            "${value.toInt()}",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: displayHeight,
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