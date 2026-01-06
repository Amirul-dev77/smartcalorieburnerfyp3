import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'utils/calculator_logic.dart';
import 'screens/login_screen.dart';

// --- MAIN ENTRY POINT ---
void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const SmartCalorieApp(),
    ),
  );
}

class SmartCalorieApp extends StatelessWidget {
  const SmartCalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Calorie Burner',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// --- MAIN NAVIGATION SCAFFOLD ---
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // The Screens based on your Wireframes
  final List<Widget> _screens = [
    const ProfileScreen(),      // Module 2
    const BMIResultScreen(),    // Module 3 [cite: 22-39]
    const CalorieTrackerScreen(), // Module 4 [cite: 40]
    const WorkoutScreen(),      // Module 5
    const CalendarScreen(),     // Module 6 [cite: 79]
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.monitor_weight), label: 'BMI/Fat'),
          NavigationDestination(icon: Icon(Icons.local_fire_department), label: 'Calorie'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
    );
  }
}

// --- MODULE 2: PROFILE INPUT SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);

    // Simple implementation of Wireframe Page 2 [cite: 9-17]
    return Scaffold(
      appBar: AppBar(title: const Text("User Profile")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // This replicates [cite: 13-17] Body Measurement inputs
          _buildInputTile("Height (cm)", user.height.toString(), (v) => user.height = double.tryParse(v) ?? user.height),
          _buildInputTile("Weight (kg)", user.weight.toString(), (v) => user.weight = double.tryParse(v) ?? user.weight),
          const Divider(),
          const Text("Body Measurements (US Navy Method)", style: TextStyle(fontWeight: FontWeight.bold)),
          _buildInputTile("Neck (cm)", user.neck.toString(), (v) => user.neck = double.tryParse(v) ?? user.neck),
          _buildInputTile("Waist/Abdomen (cm)", user.waist.toString(), (v) => user.waist = double.tryParse(v) ?? user.waist),
          _buildInputTile("Hip (cm)", user.hip.toString(), (v) => user.hip = double.tryParse(v) ?? user.hip),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => user.updateProfile(w: user.weight, h: user.height, n: user.neck, waistVal: user.waist),
            child: const Text("Update Profile & Recalculate"),
          )
        ],
      ),
    );
  }

  Widget _buildInputTile(String label, String initVal, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: initVal,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }
}

// --- MODULE 3: BMI & BODY FAT DISPLAY ---
class BMIResultScreen extends StatelessWidget {
  const BMIResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    // Wireframe Page 3 [cite: 23] and Page 4 [cite: 31]
    return Scaffold(
      appBar: AppBar(title: const Text("BMI & Body Fat")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildResultCard("Your BMI", user.bmi.toStringAsFixed(1), CalculatorLogic.getBMICategory(user.bmi), Colors.blue),
            const SizedBox(height: 10),
            _buildResultCard("Body Fat %", user.bodyFat.toStringAsFixed(1), "Calculated via Navy Method", Colors.orange),

            const SizedBox(height: 20),
            // Replicating [cite: 25] BMI Formula display
            const Text("BMI Formula: Weight (kg) / [Height (m)]²"),
            const Text("Navy Method used for Body Fat"),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, String value, String subtitle, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}

// --- MODULE 4: CALORIE TRACKER ---
class CalorieTrackerScreen extends StatelessWidget {
  const CalorieTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);

    // Replicating Wireframe Page 5 [cite: 45] formula: Goal - Food + Exercise = Remaining
    return Scaffold(
      appBar: AppBar(title: const Text("Calorie Tracker")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                const Text("Remaining Calories", style: TextStyle(fontSize: 16)),
                Text("${user.remainingCalories}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat("Goal", "${user.calorieGoal}"),
                    _stat("Food", "-${user.foodIntake}"),
                    _stat("Exercise", "+${user.exerciseBurned}"),
                  ],
                )
              ],
            ),
          ),
          // Replicating [cite: 47-53] Meal List
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.fastfood, color: Colors.orange),
                  title: const Text("Add Meal"),
                  trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => user.addFood(500)), // Dummy add
                ),
                ListTile(
                  leading: const Icon(Icons.directions_run, color: Colors.green),
                  title: const Text("Add Exercise"),
                  trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => user.addExercise(200)), // Dummy add
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

// --- MODULE 5: WORKOUT SUGGESTIONS ---
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);

    // Logic: Suggest workout based on excess calories [cite: 72-73]
    bool needsCardio = user.bmi > 25;

    return Scaffold(
      appBar: AppBar(title: const Text("Workout Plan")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Suggestion based on BMI: ${user.bmi.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          // Dynamic suggestion based on Module 5 logic
          if (needsCardio)
            _workoutCard("High Intensity Cardio", "To burn excess fat", "400 cal")
          else
            _workoutCard("Strength Training", "To build muscle mass", "250 cal"),

          _workoutCard("Cycling", "Daily maintenance", "300 cal"),
        ],
      ),
    );
  }

  Widget _workoutCard(String title, String subtitle, String cal) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(cal, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

// --- MODULE 6: CALENDAR STUB ---
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder for TableCalendar implementation [cite: 79]
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: const Center(child: Text("Calendar Widget Implementation")),
    );
  }
}