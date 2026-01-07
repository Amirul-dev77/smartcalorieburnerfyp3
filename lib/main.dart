import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Provider.of<UserProvider>(context, listen: false).fetchUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const MainScaffold();
    } else {
      return const LoginScreen();
    }
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 1;

  final List<Widget> _screens = [
    const ProfileScreen(),
    const DashboardTab(),
    const PlaceholderWidget(text: "Calorie Tracker"),
    const PlaceholderWidget(text: "Workout Page"),
    const PlaceholderWidget(text: "Calendar Page"),
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

// --- UPDATED DASHBOARD (Showing Clear Categories) ---
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final bool isMale = user.gender.toLowerCase() == 'male';

    return Scaffold(
      appBar: AppBar(
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

                      // BIG BMI VALUE
                      Text(
                        user.bmi.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white),
                      ),

                      // DYNAMIC CATEGORY DISPLAY
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: user.statusColor.withOpacity(0.2), // Dynamic color
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: user.statusColor, width: 1.5),
                        ),
                        child: Text(
                          user.bmiCategory.toUpperCase(), // "NORMAL", "OVERWEIGHT" etc.
                          style: TextStyle(
                              color: user.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // BODY FAT DISPLAY
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
                  const Icon(FontAwesomeIcons.heartPulse, size: 80, color: Colors.white24),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- B. BMI INFO CARD ---
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
                    _buildRow("Your Category", user.bmiCategory, isHighlight: true), // CLEARLY SHOWS CATEGORY
                    const Divider(height: 20),

                    const Text("BMI Categories Reference", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),

                    // The table highlights the user's current row
                    _buildCategoryRow("Underweight", "< 18.5", Colors.blue, user.bmiCategory == "Underweight"),
                    _buildCategoryRow("Normal", "18.5 - 24.9", Colors.green, user.bmiCategory == "Normal"),
                    _buildCategoryRow("Overweight", "25 - 29.9", Colors.orange, user.bmiCategory == "Overweight"),
                    _buildCategoryRow("Obese", "30+", Colors.red, user.bmiCategory == "Obese"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- C. BODY FAT INFO CARD ---
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
                    _buildRow("Your Category", user.bodyFatCategory, isHighlight: true), // CLEARLY SHOWS CATEGORY
                    const Divider(height: 20),

                    Text("Body Fat Categories Reference (${isMale ? 'Men' : 'Women'})",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),

                    if (isMale) ...[
                      _buildCategoryRow("Essential Fat", "2 - 5%", Colors.blue, user.bodyFatCategory == "Essential Fat"),
                      _buildCategoryRow("Athletes", "6 - 13%", Colors.green, user.bodyFatCategory == "Athlete"),
                      _buildCategoryRow("Fitness", "14 - 17%", Colors.green, user.bodyFatCategory == "Fitness"),
                      _buildCategoryRow("Average", "18 - 24%", Colors.orange, user.bodyFatCategory == "Average"),
                      _buildCategoryRow("Obese", "25% +", Colors.red, user.bodyFatCategory == "Obese"),
                    ] else ...[
                      _buildCategoryRow("Essential Fat", "10 - 13%", Colors.blue, user.bodyFatCategory == "Essential Fat"),
                      _buildCategoryRow("Athletes", "14 - 20%", Colors.green, user.bodyFatCategory == "Athlete"),
                      _buildCategoryRow("Fitness", "21 - 24%", Colors.green, user.bodyFatCategory == "Fitness"),
                      _buildCategoryRow("Average", "25 - 31%", Colors.orange, user.bodyFatCategory == "Average"),
                      _buildCategoryRow("Obese", "32% +", Colors.red, user.bodyFatCategory == "Obese"),
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

  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.deepPurple : Colors.black, // Purple if it's the "Your Category" line
                  fontSize: isHighlight ? 16 : 14
              )
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String label, String range, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      decoration: isActive ? BoxDecoration(
          color: color.withOpacity(0.1), // Highlight background if this is the user's category
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5))
      ) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              const SizedBox(width: 8),
              Text(
                  label,
                  style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal) // Bold if active
              ),
            ],
          ),
          Text(range, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String text;
  const PlaceholderWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: const TextStyle(fontSize: 24, color: Colors.grey)));
  }
}