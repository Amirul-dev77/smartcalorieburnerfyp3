import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../main.dart';
import '../utils/calculator_logic.dart';

class LifestyleAssessmentScreen extends StatefulWidget {
  final String name;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final double neck;
  final double abdomen;
  final double waist;
  final double hip;

  const LifestyleAssessmentScreen({
    super.key,
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.neck,
    required this.abdomen,
    required this.waist,
    required this.hip,
  });

  @override
  State<LifestyleAssessmentScreen> createState() => _LifestyleAssessmentScreenState();
}

class _LifestyleAssessmentScreenState extends State<LifestyleAssessmentScreen> {
  int _workStyle = 0;
  double _exerciseDays = 0;
  int _dailyMovement = 0;
  int _timeAvailability = 1;
  int _goal = 0;

  Future<void> _calculateAndSave() async {
    // 1. Calculate the Lifestyle String (e.g., "Moderate")
    String calculatedActivityLevel = CalculatorLogic.determineLifestyleExtended(
      workStyle: _workStyle,
      exerciseDays: _exerciseDays.toInt(),
      dailyMovement: _dailyMovement,
    );

    // 2. Calculate the Target Calories
    double bmr = CalculatorLogic.calculateBMR(
        gender: widget.gender,
        weight: widget.weight,
        height: widget.height,
        age: widget.age
    );
    double tdee = CalculatorLogic.calculateTDEE(bmr, calculatedActivityLevel);
    double targetCalories = CalculatorLogic.calculateTargetCalories(tdee, _goal);

    double relevantWaist = (widget.gender == 'male') ? widget.abdomen : widget.waist;

    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 3. Update Local Provider
    userProvider.updateProfile(
      w: widget.weight,
      h: widget.height,
      n: widget.neck,
      waistVal: relevantWaist,
      hipVal: (widget.gender == 'female') ? widget.hip : 0,
      userAge: widget.age,
    );
    userProvider.name = widget.name;
    userProvider.gender = widget.gender;
    userProvider.activityLevel = calculatedActivityLevel;

    // 4. Save everything to Firebase
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator())
      );

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'name': widget.name,
          'email': currentUser.email,
          'gender': widget.gender,
          'age': widget.age,
          'height': widget.height,
          'weight': widget.weight,
          'neck': widget.neck,
          'waist': (widget.gender == 'female') ? widget.waist : 0,
          'hip': (widget.gender == 'female') ? widget.hip : 0,
          'abdomen': (widget.gender == 'male') ? widget.abdomen : 0,
          'activityLevel': calculatedActivityLevel,
          'timeAvailability': _timeAvailability, // 0: 15min, 1: 30min, 2: 60min+
          'goal': _goal,                         // 0: Fat Loss, 1: Maintain, 2: Muscle
          'targetCalories': targetCalories.round(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        await currentUser.updateDisplayName(widget.name);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Navigate to main app layout
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScaffold()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lifestyle Assessment"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Let's customize your fitness plan.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: "Step 1: Work Style",
              child: Wrap(
                spacing: 10,
                children: [
                  _buildChip("Sitting", 0, _workStyle, (val) => setState(() => _workStyle = val)),
                  _buildChip("Mixed", 1, _workStyle, (val) => setState(() => _workStyle = val)),
                  _buildChip("Active Job", 2, _workStyle, (val) => setState(() => _workStyle = val)),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Step 2: Exercise Frequency",
              child: Column(
                children: [
                  Text("${_exerciseDays.toInt()} days per week", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Slider(
                    value: _exerciseDays,
                    min: 0,
                    max: 7,
                    divisions: 7,
                    activeColor: primaryColor,
                    onChanged: (val) => setState(() => _exerciseDays = val),
                  ),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Step 3: Daily Movement",
              subtitle: "How active are you outside workouts?",
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildChip("Minimal", 0, _dailyMovement, (val) => setState(() => _dailyMovement = val)),
                  _buildChip("Moderate", 1, _dailyMovement, (val) => setState(() => _dailyMovement = val)),
                  _buildChip("High", 2, _dailyMovement, (val) => setState(() => _dailyMovement = val)),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Step 4: Time Availability",
              child: Wrap(
                spacing: 10,
                children: [
                  _buildChip("15 min", 0, _timeAvailability, (val) => setState(() => _timeAvailability = val)),
                  _buildChip("30 min", 1, _timeAvailability, (val) => setState(() => _timeAvailability = val)),
                  _buildChip("1 hour+", 2, _timeAvailability, (val) => setState(() => _timeAvailability = val)),
                ],
              ),
            ),

            _buildSectionCard(
              title: "Step 5: Goal",
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildChip("Lose Fat", 0, _goal, (val) => setState(() => _goal = val)),
                  _buildChip("Maintain", 1, _goal, (val) => setState(() => _goal = val)),
                  _buildChip("Build Muscle", 2, _goal, (val) => setState(() => _goal = val)),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _calculateAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Calculate & Build My Plan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, String? subtitle, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int index, int selectedIndex, Function(int) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedIndex == index,
      onSelected: (bool selected) {
        if (selected) onSelected(index);
      },
    );
  }
}