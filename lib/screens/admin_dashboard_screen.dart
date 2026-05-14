import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _durCtrl = TextEditingController();

  String _selectedType = 'strength';

  // Smart Match Tags
  final List<String> _lifestyleOptions = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
  final List<String> _bmiOptions = ['Underweight', 'Normal', 'Overweight', 'Obese'];

  final List<String> _selectedLifestyles = [];
  final List<String> _selectedBmis = [];

  bool _isLoading = false;

  void _addRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLifestyles.isEmpty || _selectedBmis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one Lifestyle and BMI tag!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('routines').add({
        'title': _titleCtrl.text.trim(),
        'type': _selectedType,
        'desc': _descCtrl.text.trim(),
        'calories': int.parse(_calCtrl.text.trim()),
        'duration': '${_durCtrl.text.trim()} mins',
        'lifestyle': _selectedLifestyles,
        'bmi': _selectedBmis,
        'created_at': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear(); _descCtrl.clear(); _durCtrl.clear(); _calCtrl.clear();
      setState(() { _selectedLifestyles.clear(); _selectedBmis.clear(); });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Routine added to global pool!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteRoutine(String docId) async {
    await FirebaseFirestore.instance.collection('routines').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Admin Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(icon: Icon(Icons.add_box), text: "Add Routine"),
              Tab(icon: Icon(Icons.list), text: "Manage Added"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: ADD ROUTINE FORM
            _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_titleCtrl, "Routine Title", TextInputType.text),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(labelText: "Workout Type", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                      items: const [
                        DropdownMenuItem(value: 'strength', child: Text("Strength (Weights/Reps)")),
                        DropdownMenuItem(value: 'cardio', child: Text("Cardio (Distance/Time)")),
                      ],
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(_descCtrl, "Description / Exercises", TextInputType.multiline, maxLines: 3),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_durCtrl, "Mins", TextInputType.number)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildTextField(_calCtrl, "Kcal Burn", TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 25),

                    const Text("Target Lifestyles:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: _lifestyleOptions.map((life) {
                        return FilterChip(
                          label: Text(life, style: const TextStyle(fontSize: 12)),
                          selected: _selectedLifestyles.contains(life),
                          selectedColor: Colors.deepPurple.withOpacity(0.2),
                          onSelected: (bool selected) => setState(() => selected ? _selectedLifestyles.add(life) : _selectedLifestyles.remove(life)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 15),

                    const Text("Target BMIs:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: _bmiOptions.map((bmi) {
                        return FilterChip(
                          label: Text(bmi, style: const TextStyle(fontSize: 12)),
                          selected: _selectedBmis.contains(bmi),
                          selectedColor: Colors.blue.withOpacity(0.2),
                          onSelected: (bool selected) => setState(() => selected ? _selectedBmis.add(bmi) : _selectedBmis.remove(bmi)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _addRoutine,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("Publish Routine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // TAB 2: MANAGE ROUTINES
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('routines').orderBy('created_at', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No custom routines added yet."));

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), child: Icon(data['type'] == 'cardio' ? Icons.directions_run : Icons.fitness_center, color: Colors.deepPurple)),
                          title: Text(data['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${data['calories']} kcal • ${data['duration']}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRoutine(doc.id),
                          ),
                        ),
                      );
                    },
                  );
                }
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, TextInputType type, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white),
      validator: (value) => value!.isEmpty ? "Required" : null,
    );
  }
}