import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

// =========================================================
// 1. MAIN CALORIE SCREEN (TRACKER)
// =========================================================
class CalorieScreen extends StatefulWidget {
  const CalorieScreen({super.key});

  @override
  State<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends State<CalorieScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final int _dailyGoal = 2200;

  // --- ADD ENTRY (FOOD ONLY) ---
  void _addNewEntry(String title, int calories) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calorie_logs')
        .add({
      'title': title,
      'calories': calories,
      'type': 'food', // Hardcoded to food
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- DELETE ENTRY ---
  void _deleteEntry(String docId) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calorie_logs')
        .doc(docId)
        .delete();
  }

  // --- SHOW ADD FOOD DIALOG ---
  void _showAddFoodDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController calorieController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Food 🍔"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Description (e.g. Rice)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: calorieController,
              decoration: const InputDecoration(labelText: "Calories"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && calorieController.text.isNotEmpty) {
                int cal = int.tryParse(calorieController.text) ?? 0;
                _addNewEntry(titleController.text, cal);
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat.yMMMd().format(DateTime.now());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('calorie_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        int caloriesConsumed = 0;
        int caloriesBurned = 0;
        List<QueryDocumentSnapshot> todaysDocs = [];

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? now;

            // Filter for Today
            if (timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day) {
              todaysDocs.add(doc);
              int cal = data['calories'] ?? 0;
              if (data['type'] == 'food') {
                caloriesConsumed += cal;
              } else {
                caloriesBurned += cal;
              }
            }
          }
        }

        int caloriesRemaining = _dailyGoal - caloriesConsumed + caloriesBurned;
        double progress = caloriesConsumed / _dailyGoal;
        if (progress > 1.0) progress = 1.0;
        if (progress < 0) progress = 0;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("Calorie Tracker", style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    Text(formattedDate, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),

                // --- 1. SUMMARY CARD ---
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Calories Remaining", style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 5),
                            Text("$caloriesRemaining", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                            const Text("kcal", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                              strokeWidth: 8,
                            ),
                          ),
                          const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- 2. ACTION BUTTONS (Add Food & Diary) ---
                Row(
                  children: [
                    // A. ADD FOOD BUTTON
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showAddFoodDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Column(
                          children: const [
                            Icon(FontAwesomeIcons.appleWhole, color: Colors.orange, size: 24),
                            SizedBox(height: 8),
                            Text("Add Food", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),

                    // B. DIARY BUTTON
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to History Screen (Defined below)
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CalorieHistoryScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Column(
                          children: const [
                            Icon(FontAwesomeIcons.bookOpen, color: Colors.deepPurple, size: 24),
                            SizedBox(height: 8),
                            Text("Diary", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // --- 3. RECENT ENTRIES ---
                Text("Recent Entries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 15),

                if (todaysDocs.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No entries yet today!", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todaysDocs.length,
                    itemBuilder: (context, index) {
                      final doc = todaysDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      bool isFood = data['type'] == 'food';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(isFood ? Icons.restaurant_menu : Icons.fitness_center, color: isFood ? Colors.orange : Colors.blue),
                            const SizedBox(width: 15),
                            Expanded(child: Text(data['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface))),
                            Text(
                              isFood ? "+${data['calories']}" : "-${data['calories']}",
                              style: TextStyle(fontWeight: FontWeight.bold, color: isFood ? Colors.redAccent : Colors.green),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                              onPressed: () => _deleteEntry(doc.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// 2. DIARY / HISTORY SCREEN (In the same file)
// =========================================================
class CalorieHistoryScreen extends StatelessWidget {
  const CalorieHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Food Diary 📅"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('calorie_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text("No history found.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))));
          }

          // Group by Date
          Map<String, List<DocumentSnapshot>> groupedData = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            String dateKey = DateFormat.yMMMd().format(timestamp);
            if (!groupedData.containsKey(dateKey)) {
              groupedData[dateKey] = [];
            }
            groupedData[dateKey]!.add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: groupedData.keys.length,
            itemBuilder: (context, index) {
              String date = groupedData.keys.elementAt(index);
              List<DocumentSnapshot> dayLogs = groupedData[date]!;

              // Calculate Daily Total
              int dayTotal = 0;
              for (var doc in dayLogs) {
                final d = doc.data() as Map<String, dynamic>;
                int cal = d['calories'] ?? 0;
                if (d['type'] == 'food') dayTotal += cal;
                else dayTotal -= cal;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(date, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        Text("Net: $dayTotal kcal", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  ...dayLogs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isFood = data['type'] == 'food';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(isFood ? Icons.restaurant_menu : Icons.fitness_center, size: 16, color: isFood ? Colors.orange : Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(child: Text(data['title'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface))),
                          Text(
                            isFood ? "+${data['calories']}" : "-${data['calories']}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: isFood ? Colors.redAccent : Colors.green),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 15),
                ],
              );
            },
          );
        },
      ),
    );
  }
}