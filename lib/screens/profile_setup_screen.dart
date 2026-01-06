import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import '../main.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  // --- Controllers for Input Fields ---
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _neckController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _abdomenController = TextEditingController();

  String _selectedGender = 'male';
  String _selectedActivity = 'Moderate';

  // Activity Levels matching Wireframe
  final List<String> _activityLevels = [
    'Sedentary',
    'Light',
    'Moderate',
    'Active',
    'Very Active'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _abdomenController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    // 1. Basic Validation
    if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Height and Weight are required!")),
      );
      return;
    }

    double parse(String text) => double.tryParse(text) ?? 0.0;

    // 2. Update Provider (Local State)
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Logic: Navy Formula uses Abdomen for Men, Waist for Women.
    // We save both if entered, but use the correct one for calculation.
    double relevantWaist = (_selectedGender == 'male')
        ? parse(_abdomenController.text)
        : parse(_waistController.text);

    userProvider.updateProfile(
      w: parse(_weightController.text),
      h: parse(_heightController.text),
      n: parse(_neckController.text),
      waistVal: relevantWaist,
    );
    userProvider.name = _nameController.text;
    userProvider.gender = _selectedGender;
    userProvider.activityLevel = _selectedActivity;

    // 3. Save to Firebase
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator())
      );

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'name': _nameController.text,
          'email': currentUser.email,
          'gender': _selectedGender,
          'height': parse(_heightController.text),
          'weight': parse(_weightController.text),
          'neck': parse(_neckController.text),
          'waist': parse(_waistController.text),
          'hip': parse(_hipController.text),
          'abdomen': parse(_abdomenController.text), // Added as per wireframe
          'activityLevel': _selectedActivity,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.of(context).pop(); // Close spinner

      // 4. Navigate to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScaffold()),
            (route) => false,
      );

    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving profile: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Complete your details",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),

            // --- PERSONAL DETAILS ---
            _buildSectionHeader("Personal Details"),
            _buildTextField("Display Name", _nameController, icon: Icons.person),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: "Gender",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
              items: ['male', 'female'].map((g) => DropdownMenuItem(value: g, child: Text(g.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _selectedGender = val!),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _buildTextField("Height (cm)", _heightController, isNum: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildTextField("Weight (kg)", _weightController, isNum: true)),
              ],
            ),
            const SizedBox(height: 25),

            // --- BODY MEASUREMENTS (Wireframe Item 13) ---
            _buildSectionHeader("Body Measurement"),

            _buildTextField("Neck (cm)", _neckController, isNum: true),
            const SizedBox(height: 15),
            _buildTextField("Waist (cm)", _waistController, isNum: true),
            const SizedBox(height: 15),
            _buildTextField("Hip (cm)", _hipController, isNum: true),
            const SizedBox(height: 15),
            _buildTextField("Abdomen (cm)", _abdomenController, isNum: true), // Matches Wireframe Item 17

            const SizedBox(height: 25),

            // --- LIFESTYLE (Wireframe Item 18) ---
            _buildSectionHeader("Lifestyle Activity Level"),

            DropdownButtonFormField<String>(
              value: _selectedActivity,
              decoration: const InputDecoration(
                labelText: "Activity Level",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_run),
              ),
              items: _activityLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Calculate & Continue", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNum = false, IconData? icon}) {
    return TextField(
      controller: controller,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}