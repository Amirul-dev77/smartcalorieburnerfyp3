import 'package:flutter/material.dart';
import 'lifestyle_assessment_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _neckController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _abdomenController = TextEditingController();

  String _selectedGender = 'male';

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _neckController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _abdomenController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    // Validate inputs before moving to the next screen
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

    // Parse values safely
    double parseD(String text) => double.tryParse(text) ?? 0.0;
    int parseI(String text) => int.tryParse(text) ?? 25;

    // Navigate to Lifestyle Assessment and pass the data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LifestyleAssessmentScreen(
          name: _nameController.text,
          age: parseI(_ageController.text),
          gender: _selectedGender,
          height: parseD(_heightController.text),
          weight: parseD(_weightController.text),
          neck: parseD(_neckController.text),
          abdomen: parseD(_abdomenController.text),
          waist: parseD(_waistController.text),
          hip: parseD(_hipController.text),
        ),
      ),
    );
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

            const SizedBox(height: 40),

            // Replaced the calculate button with a "Next" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Next: Lifestyle Assessment", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
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