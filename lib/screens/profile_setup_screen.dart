import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../main.dart'; // To navigate to Dashboard after saving

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // --- Controllers for Input Fields ---
  final _nameController = TextEditingController(); // [cite: 9]
  final _heightController = TextEditingController(); // [cite: 11]
  final _weightController = TextEditingController(); // [cite: 12]
  final _neckController = TextEditingController(); // [cite: 14]
  final _waistController = TextEditingController(); // [cite: 15]
  final _hipController = TextEditingController(); // [cite: 16]

  // Default values
  String _selectedGender = 'male'; // [cite: 10]
  String _selectedActivity = 'Moderate'; // [cite: 18]

  // Activity Level Options
  final List<String> _activityLevels = [
    'Sedentary',
    'Light',
    'Moderate',
    'Active',
    'Very Active'
  ];

  @override
  void dispose() {
    // Clean up controllers when the widget is removed
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  // --- Logic to Save Data ---
  void _saveAndContinue() {
    // 1. Basic Validation
    if (_heightController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _waistController.text.isEmpty ||
        _neckController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all measurements to calculate Body Fat."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Helper function to convert Text to Double
    double parse(String text) {
      return double.tryParse(text) ?? 0.0;
    }

    // 3. Save data to UserProvider (Global State)
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Update the main profile data
    userProvider.updateProfile(
      w: parse(_weightController.text),
      h: parse(_heightController.text),
      n: parse(_neckController.text),
      waistVal: parse(_waistController.text),
    );

    // Update remaining fields manually
    userProvider.name = _nameController.text;
    userProvider.gender = _selectedGender;
    userProvider.hip = parse(_hipController.text);
    userProvider.activityLevel = _selectedActivity;

    // 4. Navigate to the Dashboard (Main App)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScaffold()),
          (route) => false, // This removes the back button history
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Let's create your health profile.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 25),

            // --- SECTION 1: PERSONAL DETAILS ---
            const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
            const SizedBox(height: 15),

            _buildTextField("Display Name", _nameController, icon: Icons.person), // [cite: 9]
            const SizedBox(height: 15),

            // Gender Dropdown [cite: 10]
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
              items: ['male', 'female']
                  .map((g) => DropdownMenuItem(
                value: g,
                child: Text(g.toUpperCase()),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedGender = val!),
            ),
            const SizedBox(height: 15),

            // Height and Weight Row [cite: 11, 12]
            Row(
              children: [
                Expanded(child: _buildTextField("Height (cm)", _heightController, isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildTextField("Weight (kg)", _weightController, isNumber: true)),
              ],
            ),
            const SizedBox(height: 30),

            // --- SECTION 2: BODY MEASUREMENTS ---
            const Text("Body Measurements", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)), // [cite: 13]
            const Text("Required for US Navy Body Fat Formula", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),

            _buildTextField("Neck Circumference (cm)", _neckController, isNumber: true), // [cite: 14]
            const SizedBox(height: 15),

            // Note: For men, Waist usually refers to Abdomen circumference
            _buildTextField("Waist / Abdomen (cm)", _waistController, isNumber: true), // [cite: 15, 17]
            const SizedBox(height: 15),

            _buildTextField("Hip Circumference (cm)", _hipController, isNumber: true), // [cite: 16]
            const SizedBox(height: 30),

            // --- SECTION 3: LIFESTYLE ---
            const Text("Lifestyle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)), // [cite: 18]
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedActivity,
              decoration: const InputDecoration(
                labelText: "Activity Level",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.run_circle_outlined),
              ),
              items: _activityLevels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedActivity = val!),
            ),
            const SizedBox(height: 40),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Calculate & Start", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build text fields quickly
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, IconData? icon}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}