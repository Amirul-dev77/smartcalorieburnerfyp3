import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart'; // --- NEW: Barcode Scanner
import '../providers/user_provider.dart';

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

  // --- ADD ENTRY TO FIREBASE ---
  void _addNewEntry(String title, int calories) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('calorie_logs')
        .add({
      'title': title,
      'calories': calories,
      'type': 'food',
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

  // --- 1. NLP API CALL (Calorie Ninjas) ---
  void _showAddFoodDialog() {
    final TextEditingController foodInputController = TextEditingController();
    bool isFetching = false;
    String errorMessage = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("What did you eat? 🍔"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Just type naturally! e.g., '2 boiled eggs and a slice of toast'",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: foodInputController,
                    decoration: const InputDecoration(
                      labelText: "Your meal",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (isFetching) ...[
                    const SizedBox(height: 15),
                    const CircularProgressIndicator(),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isFetching ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isFetching
                      ? null
                      : () async {
                    if (foodInputController.text.trim().isEmpty) return;

                    setState(() {
                      isFetching = true;
                      errorMessage = "";
                    });

                    try {
                      // TODO: PASTE YOUR REAL API KEY HERE
                      const String apiKey = 'Xo5aaPKG8n+yWPPyj2L9Yw==yGp3Ve3SBX9084js';

                      // Safe URL formatting for spaces
                      final url = Uri.https('api.calorieninjas.com', '/v1/nutrition', {
                        'query': foodInputController.text
                      });

                      final response = await http.get(
                        url,
                        headers: {'X-Api-Key': apiKey},
                      );

                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);
                        final items = data['items'] as List;

                        if (items.isEmpty) {
                          setState(() {
                            errorMessage = "Couldn't recognize any food. Try being more specific!";
                            isFetching = false;
                          });
                          return;
                        }

                        double totalCalories = 0;
                        List<String> foodNames = [];

                        for (var item in items) {
                          totalCalories += item['calories'];
                          String name = item['name'].toString();
                          name = name[0].toUpperCase() + name.substring(1);
                          foodNames.add(name);
                        }

                        String combinedTitle = foodNames.join(', ');

                        _addNewEntry(combinedTitle, totalCalories.round());

                        if (context.mounted) Navigator.pop(context);

                      } else {
                        setState(() {
                          errorMessage = "API Error: ${response.statusCode}";
                          isFetching = false;
                        });
                      }
                    } catch (e) {
                      setState(() {
                        errorMessage = "Network error. Check your connection.";
                        isFetching = false;
                      });
                    }
                  },
                  child: const Text("Analyze & Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 2. BARCODE SCANNER (Open Food Facts) ---
  void _scanBarcodeAndFetch() async {
    String? res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleBarcodeScannerPage(),
      ),
    );

    if (res == null || res == '-1') return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.https('world.openfoodfacts.org', '/api/v0/product/$res.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 1) {
          final product = data['product'];

          String productName = product['product_name'] ?? 'Unknown Snack';
          num calories = product['nutriments']['energy-kcal_serving']
              ?? product['nutriments']['energy-kcal_100g']
              ?? 0;

          _addNewEntry(productName, calories.round());

          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Scanned: $productName (${calories.round()} kcal)"), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Product not found in database!"), backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error or invalid barcode."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat.yMMMd().format(DateTime.now());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- FETCH DYNAMIC GOAL ---
    final userProvider = Provider.of<UserProvider>(context);
    final int dynamicDailyGoal = userProvider.calculatedDailyGoal;

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

        // --- MATH WITH DYNAMIC GOAL ---
        int caloriesRemaining = dynamicDailyGoal - caloriesConsumed + caloriesBurned;
        double progress = caloriesConsumed / dynamicDailyGoal;
        if (progress > 1.0) progress = 1.0;
        if (progress < 0) progress = 0;

        bool isOverLimit = caloriesRemaining < 0;

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
                    gradient: LinearGradient(
                      colors: isOverLimit
                          ? [Colors.redAccent.shade100, Colors.pinkAccent.shade100]
                          : [Colors.deepPurple, Colors.purpleAccent],
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
                            Text(
                                "$caloriesRemaining",
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                            ),
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
                              value: isOverLimit ? 1.0 : progress,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                              strokeWidth: 8,
                            ),
                          ),
                          isOverLimit
                              ? const Text("😲", style: TextStyle(fontSize: 32))
                              : const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- CUTE REMINDER ---
                if (isOverLimit) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.redAccent : Colors.orangeAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.heart, color: Colors.pinkAccent, size: 24),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "It's okay!",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  "You went a little over today, but don't stress! Rest up and try again tomorrow. 🌙✨",
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.8))
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 25),

                // --- 2. ACTION BUTTONS (3 BUTTONS) ---
                Row(
                  children: [
                    // A. TYPE FOOD
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showAddFoodDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Column(
                          children: const [
                            Icon(FontAwesomeIcons.keyboard, color: Colors.orange, size: 20),
                            SizedBox(height: 5),
                            Text("Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // B. SCAN BARCODE
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _scanBarcodeAndFetch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Column(
                          children: const [
                            Icon(FontAwesomeIcons.barcode, color: Colors.blue, size: 20),
                            SizedBox(height: 5),
                            Text("Scan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // C. DIARY
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CalorieHistoryScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Column(
                          children: const [
                            Icon(FontAwesomeIcons.bookOpen, color: Colors.deepPurple, size: 20),
                            SizedBox(height: 5),
                            Text("Diary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
// 2. DIARY / HISTORY SCREEN
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
      appBar: AppBar(title: const Text("Food Diary 📅"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('calorie_logs').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text("No history found.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))));

          Map<String, List<DocumentSnapshot>> groupedData = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            String dateKey = DateFormat.yMMMd().format(timestamp);
            if (!groupedData.containsKey(dateKey)) groupedData[dateKey] = [];
            groupedData[dateKey]!.add(doc);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: groupedData.keys.length,
            itemBuilder: (context, index) {
              String date = groupedData.keys.elementAt(index);
              List<DocumentSnapshot> dayLogs = groupedData[date]!;
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
                      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1))),
                      child: Row(
                        children: [
                          Icon(isFood ? Icons.restaurant_menu : Icons.fitness_center, size: 16, color: isFood ? Colors.orange : Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(child: Text(data['title'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface))),
                          Text(isFood ? "+${data['calories']}" : "-${data['calories']}", style: TextStyle(fontWeight: FontWeight.bold, color: isFood ? Colors.redAccent : Colors.green)),
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