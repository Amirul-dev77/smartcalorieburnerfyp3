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
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(); // --- NEW ---
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _neckController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _abdomenController = TextEditingController();

  String _selectedGender = 'male';
  String _selectedActivity = 'Moderate';

  final List<String> _activityLevels = [
    'Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose(); // --- NEW ---
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _abdomenController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    // 1. Validation (Added Age)
    if (_heightController.text.isEmpty || _weightController.text.isEmpty || _ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Age, Height, and Weight are required!")));
      return;
    }

    if (_neckController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Neck is required.")));
      return;
    }
    if (_selectedGender == 'male' && _abdomenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abdomen is required for men.")));
      return;
    }
    if (_selectedGender == 'female' && (_waistController.text.isEmpty || _hipController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Waist and Hip are required for women.")));
      return;
    }

    double parseD(String text) => double.tryParse(text) ?? 0.0;
    int parseI(String text) => int.tryParse(text) ?? 25; // Helper for Age

    double relevantWaist = (_selectedGender == 'male')
        ? parseD(_abdomenController.text)
        : parseD(_waistController.text);

    // 2. Update Provider
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    userProvider.updateProfile(
      w: parseD(_weightController.text),
      h: parseD(_heightController.text),
      n: parseD(_neckController.text),
      waistVal: relevantWaist,
      hipVal: (_selectedGender == 'female') ? parseD(_hipController.text) : 0,
      userAge: parseI(_ageController.text), // --- NEW ---
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
          'age': parseI(_ageController.text), // --- NEW ---
          'height': parseD(_heightController.text),
          'weight': parseD(_weightController.text),
          'neck': parseD(_neckController.text),
          'waist': (_selectedGender == 'female') ? parseD(_waistController.text) : 0,
          'hip': (_selectedGender == 'female') ? parseD(_hipController.text) : 0,
          'abdomen': (_selectedGender == 'male') ? parseD(_abdomenController.text) : 0,
          'activityLevel': _selectedActivity,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await currentUser.updateDisplayName(_nameController.text);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

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
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text("Setup Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Complete your details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 20),

            _buildSectionHeader("Personal Details", primaryColor),
            _buildTextField("Display Name", _nameController, icon: Icons.person),
            const SizedBox(height: 15),

            // --- AGE AND GENDER ROW ---
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextField("Age", _ageController, isNum: true),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
                    items: ['male', 'female'].map((g) => DropdownMenuItem(value: g, child: Text(g.toUpperCase()))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedGender = val!;
                        if(_selectedGender == 'male') {
                          _waistController.clear(); _hipController.clear();
                        } else {
                          _abdomenController.clear();
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Row(children: [
              Expanded(child: _buildTextField("Height (cm)", _heightController, isNum: true)),
              const SizedBox(width: 15),
              Expanded(child: _buildTextField("Weight (kg)", _weightController, isNum: true)),
            ]),
            const SizedBox(height: 25),

            // ... The rest of your Body Measurement & Lifestyle code stays the same ...
            _buildSectionHeader("Body Measurement", primaryColor),

            _buildTextField("Neck (cm)", _neckController, isNum: true),
            const SizedBox(height: 15),

            if (_selectedGender == 'male') ...[
              _buildTextField("Abdomen (cm)", _abdomenController, isNum: true),
              const Padding(padding: EdgeInsets.only(top: 5, left: 5), child: Text("Measure around navel", style: TextStyle(fontSize: 12, color: Colors.grey))),
            ] else ...[
              _buildTextField("Waist (cm)", _waistController, isNum: true),
              const SizedBox(height: 15),
              _buildTextField("Hip (cm)", _hipController, isNum: true),
            ],

            const SizedBox(height: 25),

            _buildSectionHeader("Lifestyle", primaryColor),
            DropdownButtonFormField<String>(
              value: _selectedActivity,
              decoration: const InputDecoration(labelText: "Activity Level", border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_run)),
              items: _activityLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (val) => setState(() => _selectedActivity = val!),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
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