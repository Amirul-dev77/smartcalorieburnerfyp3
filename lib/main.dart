import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/calorie_screen.dart';
import 'screens/workout_screen.dart';

// --- APP ENTRY POINT ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Sign-in singleton as required by v7.x
  await GoogleSignIn.instance.initialize();

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

// --- AUTH WRAPPER ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Removed initState from here. This widget now just handles routing based on auth state.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const MainScaffold();
    } else {
      return const LoginScreen();
    }
  }
}

// --- MAIN SCAFFOLD ---
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 1; // Default to Dashboard (BMI)

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ProfileScreen(),
      DashboardTab(onHelpPressed: () => _showUserGuideDialog(context, forced: true)),
      const CalorieScreen(),
      const WorkoutScreen(),
      const CalendarScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final provider = Provider.of<UserProvider>(context, listen: false);
        await provider.fetchUserData();
        if (!provider.hasSeenUserGuide) {
          _showUserGuideDialog(context);
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showUserGuideDialog(BuildContext context, {bool forced = false}) {
    int currentStep = 0;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.01),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: StatefulBuilder(
            builder: (context, setDialogState) {
              final List<Map<String, dynamic>> steps = [
                {
                  'title': "Welcome to Smart Calorie Burner!",
                  'description': "Your personal Mobile fitness coach is ready to help you hit your goals. Let's take a quick 1-minute tour of your new dashboard!",
                  'icon': Icons.fitness_center,
                  'color': Colors.deepPurple,
                  'tabIndex': 1,
                  'spotlight': null,
                },
                {
                  'title': "Understand Your Health Metrics",
                  'description': "View your real-time BMI and Body Fat percentages (calculated via US Navy method). Check your status category indicator (Underweight, Normal, Overweight, Obese) to track your baseline progress.",
                  'icon': Icons.monitor_weight,
                  'color': Colors.purple,
                  'tabIndex': 1,
                  'spotlight': 'bmi_card',
                },
                {
                  'title': "Log Foods & Track Calories",
                  'description': "Monitor your BMR, TDEE, and remaining calorie budget. Log food instantly by typing ingredients with our Calorie Ninja API, or scan product barcodes using the Open Food Facts database!",
                  'icon': Icons.local_fire_department,
                  'color': Colors.orange,
                  'tabIndex': 2,
                  'spotlight': 'calorie_card',
                },
                {
                  'title': "Detailed Calorie Diary",
                  'description': "Tap 'Diary' to view your complete daily food log broken down by meals (Breakfast, Lunch, Dinner, Snacks), track calories burned from workouts, and view historical entries!",
                  'icon': Icons.menu_book,
                  'color': Colors.purpleAccent,
                  'tabIndex': 2,
                  'spotlight': 'calorie_diary_button',
                },
                {
                  'title': "Personalized Workouts",
                  'description': "Our smart matching engine recommends and ranks workout routines tailored specifically to your BMI and activity level! Routines with a 'Perfect Match' or 'Good Fit' tag are optimized for you.",
                  'icon': Icons.star,
                  'color': Colors.amber,
                  'tabIndex': 3,
                  'spotlight': 'workout_card',
                },
                {
                  'title': "Track Workouts in Real-Time",
                  'description': "Log sets, weight, and reps with automatic rest timers for Strength. For Cardio, enjoy live step counting (pedometer sensor) and GPS location tracking for distance, pace, speed, and exact active calorie burning!",
                  'icon': Icons.sensors,
                  'color': Colors.blue,
                  'tabIndex': 3,
                  'spotlight': 'workout_start_button',
                },
                {
                  'title': "Time Travel & Calendar History",
                  'description': "Keep track of your workout streak with the interactive calendar! View logged exercises, daily stats, and monthly counts. You can even check past details by selecting any previous date.",
                  'icon': Icons.calendar_month,
                  'color': Colors.teal,
                  'tabIndex': 4,
                  'spotlight': null,
                },
                {
                  'title': "Keep Your Profile Updated",
                  'description': "Update your age, activity level, goal, and body measurements (waist, neck, hips) at any time by tapping the 'Edit Profile' button! The system will instantly recalculate your calorie targets and match scores.",
                  'icon': Icons.person,
                  'color': Colors.deepPurple,
                  'tabIndex': 0,
                  'spotlight': 'edit_profile_button',
                },
                {
                  'title': "Access the Interactive Tour Anytime!",
                  'description': "You can replay this step-by-step game tutorial at any time by clicking this help icon in the top right corner of the Dashboard!",
                  'icon': Icons.help_outline,
                  'color': Colors.deepPurple,
                  'tabIndex': 1,
                  'spotlight': 'help_button',
                },
                {
                  'title': "You're All Set!",
                  'description': "Your journey starts now. Keep logging meals, complete workouts, and achieve your dream physique! Let's burn some calories!",
                  'icon': Icons.rocket_launch,
                  'color': Colors.orange,
                  'tabIndex': 1,
                  'spotlight': null,
                },
              ];

              final size = MediaQuery.of(context).size;
              Offset? spotlightCenter;
              double? spotlightRadius;
              Rect? spotlightRect;
              String? arrowDirection;
              double? arrowX;
              double? arrowY;
              double? dialogTop;
              double? dialogBottom;

              final step = steps[currentStep];
              final spotlight = step['spotlight'];

              if (spotlight == 'bmi_card') {
                spotlightRect = Rect.fromLTWH(16, 110, size.width - 32, 220);
              } else if (spotlight == 'calorie_card') {
                spotlightRect = Rect.fromLTWH(16, 140, size.width - 32, 220);
              } else if (spotlight == 'calorie_diary_button') {
                spotlightRect = Rect.fromLTWH(size.width * 0.75 - 25 - 8, 385, 116, 92);
              } else if (spotlight == 'workout_card') {
                spotlightRect = Rect.fromLTWH(16, 150, size.width - 32, 220);
              } else if (spotlight == 'workout_start_button') {
                spotlightRect = Rect.fromLTWH(16, 324, size.width - 32, 48);
              } else if (spotlight == 'calendar_card') {
                spotlightRect = Rect.fromLTWH(15, 150, size.width - 30, 510);
              } else if (spotlight == 'edit_profile_button') {
                spotlightRect = Rect.fromLTWH(size.width / 2 - 90, 325, 180, 52);
              } else if (spotlight == 'help_button') {
                spotlightCenter = Offset(size.width - 76, 52);
                spotlightRadius = 26;
                arrowDirection = 'up';
                arrowX = size.width - 76;
                arrowY = 82;
                dialogTop = 135;
              }

              // Determine arrow and dialog positioning dynamically based on spotlightRect
              if (spotlightRect != null) {
                arrowX = size.width / 2;
                if (spotlightRect.bottom > 400) {
                  // Element is low on screen, place dialog ABOVE spotlight
                  arrowDirection = 'down';
                  arrowY = spotlightRect.top - 45;
                  dialogBottom = size.height - spotlightRect.top + 15;
                } else {
                  // Element is high on screen, place dialog BELOW spotlight
                  arrowDirection = 'up';
                  arrowY = spotlightRect.bottom + 5;
                  dialogTop = spotlightRect.bottom + 50;
                }
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SpotlightPainter(
                        center: spotlightCenter,
                        radius: spotlightRadius,
                        rect: spotlightRect,
                        cornerRadius: spotlight == 'edit_profile_button' ? 26 : 16,
                      ),
                    ),
                  ),
                  if (arrowDirection != null && arrowX != null && arrowY != null)
                    Positioned(
                      left: arrowX - 20,
                      top: arrowY,
                      child: GamingPulsingArrow(
                        icon: arrowDirection == 'up'
                            ? Icons.keyboard_double_arrow_up
                            : Icons.keyboard_double_arrow_down,
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: spotlight == null
                        ? (size.height / 2 - 180)
                        : dialogTop,
                    bottom: dialogBottom,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E1B4B),
                              Color(0xFF311042),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.amberAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withOpacity(0.35),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    "QUEST TUTORIAL: ${currentStep + 1} / ${steps.length}",
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                if (currentStep < steps.length - 1)
                                  TextButton(
                                    onPressed: () {
                                      userProvider.completeUserGuide();
                                      Navigator.pop(dialogContext);
                                    },
                                    child: const Text(
                                      "SKIP QUEST",
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (step['color'] as Color).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: step['color'] as Color, width: 1.5),
                                  ),
                                  child: Icon(
                                    step['icon'] as IconData,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    step['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  step['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFE2E8F0),
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(steps.length, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: currentStep == index ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: currentStep == index ? Colors.amberAccent : Colors.white30,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (currentStep > 0)
                                  OutlinedButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        currentStep--;
                                        _onItemTapped(steps[currentStep]['tabIndex'] as int);
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                      side: const BorderSide(color: Colors.white30),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      "BACK",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                ElevatedButton(
                                  onPressed: () {
                                    if (currentStep < steps.length - 1) {
                                      setDialogState(() {
                                        currentStep++;
                                        _onItemTapped(steps[currentStep]['tabIndex'] as int);
                                      });
                                    } else {
                                      userProvider.completeUserGuide();
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    currentStep == steps.length - 1 ? "GOT IT!" : "NEXT",
                                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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

// --- DASHBOARD TAB (BMI Page) ---
class DashboardTab extends StatelessWidget {
  final VoidCallback? onHelpPressed;
  const DashboardTab({super.key, this.onHelpPressed});

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
            Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: false,
        actions: [
          if (onHelpPressed != null)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: onHelpPressed,
              tooltip: "User Onboarding Tour",
            ),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BMI CARD
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
                      Text(
                        user.bmi.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: user.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: user.statusColor, width: 1.5),
                        ),
                        child: Text(
                          user.bmiCategory.toUpperCase(),
                          style: TextStyle(
                              color: user.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
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

            // BMI DETAILS
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
                    _buildRow("Your Category", user.bmiCategory, isHighlight: true),
                    const Divider(height: 20),
                    const Text("BMI Categories Reference", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    const SizedBox(height: 10),
                    _buildCategoryRow("Underweight", "< 18.5", Colors.blue, user.bmiCategory == "Underweight"),
                    _buildCategoryRow("Normal", "18.5 - 24.9", Colors.green, user.bmiCategory == "Normal"),
                    _buildCategoryRow("Overweight", "25 - 29.9", Colors.orange, user.bmiCategory == "Overweight"),
                    _buildCategoryRow("Obese", "30+", Colors.red, user.bmiCategory == "Obese"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // BODY FAT DETAILS
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
                    _buildRow("Your Category", user.bodyFatCategory, isHighlight: true),
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

  // --- Helper Widgets ---
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
                  color: isHighlight ? Colors.deepPurple : Colors.black,
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
          color: color.withOpacity(0.1),
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
                  style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)
              ),
            ],
          ),
          Text(range, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- GAMING SPOTLIGHT TUTORIAL MASK CUTOUT PAINTER ---
class SpotlightPainter extends CustomPainter {
  final Offset? center;
  final double? radius;
  final Rect? rect;
  final double cornerRadius;

  SpotlightPainter({this.center, this.radius, this.rect, this.cornerRadius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.78);

    if (center == null && rect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    
    // Draw dimming background overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Clear target spotlight region using BlendMode.clear
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (center != null && radius != null) {
      canvas.drawCircle(center!, radius!, clearPaint);
    } else if (rect != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect!, Radius.circular(cornerRadius)), clearPaint);
    }

    canvas.restore();

    // Draw glowing neon gold outline around the spotlight target region
    final borderPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    if (center != null && radius != null) {
      canvas.drawCircle(center!, radius!, borderPaint);
    } else if (rect != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect!, Radius.circular(cornerRadius)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius || oldDelegate.rect != rect;
  }
}

// --- GAMING-STYLE LOOPING PULSING ARROW INDICATOR ---
class GamingPulsingArrow extends StatefulWidget {
  final IconData icon;
  const GamingPulsingArrow({super.key, required this.icon});

  @override
  State<GamingPulsingArrow> createState() => _GamingPulsingArrowState();
}

class _GamingPulsingArrowState extends State<GamingPulsingArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Icon(
            widget.icon,
            color: Colors.amberAccent,
            size: 40,
            shadows: [
              Shadow(color: Colors.amberAccent.withOpacity(0.8), blurRadius: 12),
            ],
          ),
        );
      },
    );
  }
}