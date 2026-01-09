import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // Used for formatting dates

class CalorieScreen extends StatefulWidget {
  const CalorieScreen({super.key});

  @override
  State<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends State<CalorieScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final int _dailyGoal = 2200; // You can make this dynamic later based on Profile

  // --- 1. FUNCTION: ADD ENTRY TO FIREBASE ---
  void _addNewEntry(String title, int calories, String type) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calorie_logs')
        .add({
      'title': title,
      'calories': calories,
      'type': type, // 'food' or 'workout'
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- 2. FUNCTION: DELETE ENTRY FROM FIREBASE ---
  void _deleteEntry(String docId) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calorie_logs')
        .doc(docId)
        .delete();
  }

  // --- 3. UI: SHOW INPUT DIALOG ---
  void _showAddDialog(String type) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController calorieController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'food' ? "Add Food 🍔" : "Add Workout 🏃"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Description (e.g. Chicken Rice)"),
            ),
            TextField(
              controller: calorieController,
              decoration: const InputDecoration(labelText: "Calories (e.g. 500)"),
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
                // Parse calories and save
                int cal = int.tryParse(calorieController.text) ?? 0;
                _addNewEntry(titleController.text, cal, type);
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
    // Get today's date formatted
    String formattedDate = DateFormat.yMMMd().format(DateTime.now());

    // --- STREAM BUILDER: LISTENS TO FIREBASE CHANGES ---
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('calorie_logs')
          .orderBy('timestamp', descending: true) // Newest first
          .snapshots(),
      builder: (context, snapshot) {

        // A. CALCULATE TOTALS ON THE FLY
        int caloriesConsumed = 0;
        int caloriesBurned = 0;
        List<QueryDocumentSnapshot> todaysDocs = [];

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? now;

            // Only calculate for TODAY
            if (timestamp.year == now.year && timestamp.month == now.month && timestamp.day == now.day) {
              todaysDocs.add(doc); // Add to local list for the ListView
              int cal = data['calories'] ?? 0;
              if (data['type'] == 'food') {
                caloriesConsumed += cal;
              } else {
                caloriesBurned += cal;
              }
            }
          }
        }

        // B. CALCULATE PROGRESS MATH
        int caloriesRemaining = _dailyGoal - caloriesConsumed + caloriesBurned;
        double progress = caloriesConsumed / _dailyGoal;
        if (progress > 1.0) progress = 1.0;
        if (progress < 0) progress = 0;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text("Calorie Tracker", style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- DATE HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),

                // --- MAIN SUMMARY CARD ---
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurple.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Calories Remaining", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 5),
                            Text("$caloriesRemaining", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                            const Text("kcal", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _buildMiniStat("Base Goal", "$_dailyGoal"),
                                const SizedBox(width: 15),
                                _buildMiniStat("Burned", "$caloriesBurned", isBurned: true),
                              ],
                            )
                          ],
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100, height: 100,
                            child: CircularProgressIndicator(value: 1.0, strokeWidth: 10, color: Colors.white.withOpacity(0.2)),
                          ),
                          SizedBox(
                            width: 100, height: 100,
                            child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor: Colors.transparent,
                                color: Colors.white,
                                strokeCap: StrokeCap.round
                            ),
                          ),
                          const Icon(Icons.local_fire_department, color: Colors.white, size: 30),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // --- ACTION BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: FontAwesomeIcons.appleWhole,
                        label: "Add Food",
                        color: Colors.orange,
                        onTap: () => _showAddDialog('food'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildActionButton(
                        icon: FontAwesomeIcons.personRunning,
                        label: "Add Workout",
                        color: Colors.blue,
                        onTap: () => _showAddDialog('workout'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // --- RECENT ENTRIES LIST ---
                const Text("Recent Entries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // THE LIST VIEW (Dynamically built from Firebase data)
                todaysDocs.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No entries yet today!")))
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todaysDocs.length,
                  itemBuilder: (context, index) {
                    final doc = todaysDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildEntryItem(
                      doc.id, // We need ID to delete
                      data['title'] ?? 'Unknown',
                      data['calories']?.toString() ?? '0',
                      data['type'] == 'food',
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

  // --- WIDGET HELPER: MINI STATS ---
  Widget _buildMiniStat(String label, String value, {bool isBurned = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: isBurned ? Colors.lightGreenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // --- WIDGET HELPER: ACTION BUTTONS ---
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: LIST ITEM WITH DELETE ---
  Widget _buildEntryItem(String docId, String title, String calories, bool isFood) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isFood ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isFood ? Icons.restaurant_menu : Icons.fitness_center, color: isFood ? Colors.orange : Colors.blue, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Text(
            isFood ? "+$calories" : "-$calories",
            style: TextStyle(fontWeight: FontWeight.bold, color: isFood ? Colors.redAccent : Colors.green),
          ),
          // DELETE BUTTON (Trash Can)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
            onPressed: () => _deleteEntry(docId),
          ),
        ],
      ),
    );
  }
}