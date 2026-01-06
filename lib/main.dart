import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart'; // Required for the Profile Tab

// --- 1. APP ENTRY POINT ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const SmartCalorieApp(),
    ),
  );
}

// --- 2. ROOT WIDGET ---
class SmartCalorieApp extends StatelessWidget {
  const SmartCalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Calorie Burner',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const LoginScreen(),
    );
  }
}

// --- 3. MAIN NAVIGATION (Bottom Tabs) ---
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 1; // Start at 'BMI' (Dashboard) by default

  // Screen List
  final List<Widget> _screens = [
    const ProfileScreen(),             // 0: Profile
    const DashboardTab(),              // 1: BMI / Dashboard (Updated)
    const PlaceholderWidget(text: "Calorie Tracker"), // 2: Calorie
    const PlaceholderWidget(text: "Workout Page"),    // 3: Workout
    const PlaceholderWidget(text: "Calendar Page"),   // 4: Calendar
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: 'BMI',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Calorie',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}

// --- 4. DASHBOARD TAB (BMI Page - UPDATED) ---
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Access User Data
    final user = Provider.of<UserProvider>(context);

    // Check gender for specific Body Fat categories
    final bool isMale = user.gender.toLowerCase() == 'male';

    return Scaffold(
      appBar: AppBar(
        // Dynamic Name Greeting
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome back,", style: TextStyle(fontSize: 14, color: Colors.grey)),
            Text("Hi, ${user.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- A. MAIN BMI & BODY FAT CARD ---
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("YOUR BMI", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.5)),
                      const SizedBox(height: 5),
                      Text(
                        user.bmi.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Body Fat: ${user.bodyFat.toStringAsFixed(1)}%",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Icon(FontAwesomeIcons.heartPulse, size: 70, color: Colors.white24),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- B. BMI INFO CARD (Formula & Categories) ---
            const Text("BMI Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildRow("BMI Formula", "Weight(kg) / Height(m)²"),
                    const Divider(height: 20),
                    const Text("BMI Categories", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),
                    _buildCategoryRow("Underweight", "< 18.5", Colors.blue),
                    _buildCategoryRow("Normal", "18.5 - 24.9", Colors.green),
                    _buildCategoryRow("Overweight", "25 - 29.9", Colors.orange),
                    _buildCategoryRow("Obese", "30+", Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- C. BODY FAT INFO CARD (Formula & Categories) ---
            const Text("Body Fat Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildRow("Method", "US Navy Method"),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "(Calculated using Height, Neck, Waist, & Hip)",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(height: 20),
                    Text("Body Fat Categories (${isMale ? 'Men' : 'Women'})",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),

                    // Display different ranges based on Gender
                    if (isMale) ...[
                      _buildCategoryRow("Essential Fat", "2 - 5%", Colors.blue),
                      _buildCategoryRow("Athletes", "6 - 13%", Colors.green),
                      _buildCategoryRow("Fitness", "14 - 17%", Colors.green),
                      _buildCategoryRow("Average", "18 - 24%", Colors.orange),
                      _buildCategoryRow("Obese", "25% +", Colors.red),
                    ] else ...[
                      _buildCategoryRow("Essential Fat", "10 - 13%", Colors.blue),
                      _buildCategoryRow("Athletes", "14 - 20%", Colors.green),
                      _buildCategoryRow("Fitness", "21 - 24%", Colors.green),
                      _buildCategoryRow("Average", "25 - 31%", Colors.orange),
                      _buildCategoryRow("Obese", "32% +", Colors.red),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets for the Tables ---

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCategoryRow(String label, String range, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(range, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- 5. PLACEHOLDER FOR EMPTY TABS ---
class PlaceholderWidget extends StatelessWidget {
  final String text;
  const PlaceholderWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: const TextStyle(fontSize: 24, color: Colors.grey)));
  }
}