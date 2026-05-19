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
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _durCtrl = TextEditingController();

  // DYNAMIC EXERCISE CONTROLLERS
  final TextEditingController _descCtrl = TextEditingController(); // Used for Cardio
  List<TextEditingController> _exerciseCtrls = [TextEditingController()]; // Used for Strength

  String _selectedType = 'strength';

  // Smart Match Tags
  final List<String> _lifestyleOptions = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
  final List<String> _bmiOptions = ['Underweight', 'Normal', 'Overweight', 'Obese'];

  final List<String> _selectedLifestyles = [];
  final List<String> _selectedBmis = [];

  bool _isLoading = false;

  final List<Map<String, dynamic>> _defaultRoutines = [
    {'title': 'Push Workout', 'type': 'strength', 'calories': 250, 'duration': '45 mins'},
    {'title': 'Pull Workout', 'type': 'strength', 'calories': 230, 'duration': '45 mins'},
    {'title': 'Legs Workout', 'type': 'strength', 'calories': 350, 'duration': '50 mins'},
    {'title': 'Outdoor Running', 'type': 'cardio', 'calories': 400, 'duration': '30 mins'},
    {'title': 'Brisk Walking', 'type': 'cardio', 'calories': 150, 'duration': '30 mins'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _calCtrl.dispose(); _durCtrl.dispose();
    for (var ctrl in _exerciseCtrls) { ctrl.dispose(); }
    super.dispose();
  }

  void _addRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLifestyles.isEmpty || _selectedBmis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one Lifestyle and BMI tag!"), backgroundColor: Colors.orange));
      return;
    }

    // 👉 DYNAMIC ENGINE: Check what type of routine we are saving
    List<String> exercisesList = [];
    String finalDesc = _descCtrl.text.trim();

    if (_selectedType == 'strength') {
      exercisesList = _exerciseCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (exercisesList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one exercise!"), backgroundColor: Colors.orange));
        return;
      }
      finalDesc = exercisesList.join(', '); // Creates a clean string for the display list
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('routines').add({
        'title': _titleCtrl.text.trim(),
        'type': _selectedType,
        'desc': finalDesc,
        'exercises': exercisesList,
        'calories': int.parse(_calCtrl.text.trim()),
        'duration': '${_durCtrl.text.trim()} mins',
        'lifestyle': _selectedLifestyles,
        'bmi': _selectedBmis,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Clear the form
      _titleCtrl.clear(); _descCtrl.clear(); _durCtrl.clear(); _calCtrl.clear();
      setState(() {
        _selectedLifestyles.clear(); _selectedBmis.clear();
        _exerciseCtrls = [TextEditingController()];
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Routine added to global pool!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteRoutine(String docId) async {
    await FirebaseFirestore.instance.collection('routines').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Custom routine deleted."), backgroundColor: Colors.orange));
    }
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
              // 👉 SWAPPED TABS HERE
              Tab(icon: Icon(Icons.list), text: "Manage Routines"),
              Tab(icon: Icon(Icons.add_box), text: "Add Routine"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 👉 SWAPPED SCREENS HERE
            // TAB 1 (NOW MANAGE ROUTINES): List of current routines
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('routines').orderBy('created_at', descending: true).snapshots(),
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> allRoutines = _defaultRoutines.map((e) {
                    return {...e, 'isDefault': true};
                  }).toList();

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    var firebaseRoutines = snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      data['isDefault'] = false;
                      return data;
                    }).toList();
                    allRoutines.addAll(firebaseRoutines);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: allRoutines.length,
                    itemBuilder: (context, index) {
                      var data = allRoutines[index];
                      bool isDefault = data['isDefault'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isDefault ? Colors.transparent : Colors.deepPurple.withOpacity(0.3))
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.withOpacity(0.1),
                              child: Icon(data['type'] == 'cardio' ? Icons.directions_run : Icons.fitness_center, color: Colors.deepPurple)
                          ),
                          title: Text(data['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${data['calories']} kcal • ${data['duration']}"),
                          trailing: isDefault
                              ? Tooltip(message: "System Default", child: Icon(Icons.lock_outline, color: Colors.grey.shade400))
                              : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRoutine(data['id'])),
                        ),
                      );
                    },
                  );
                }
            ),

            // TAB 2 (NOW ADD ROUTINE): The dynamic creation form
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

                    if (_selectedType == 'strength') ...[
                      const Text("Exercises in this routine:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...List.generate(_exerciseCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(child: _buildTextField(_exerciseCtrls[index], "Exercise ${index + 1} (e.g., Bench Press)", TextInputType.text)),
                              if (_exerciseCtrls.length > 1)
                                IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => setState(() => _exerciseCtrls.removeAt(index))
                                ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                          onPressed: () => setState(() => _exerciseCtrls.add(TextEditingController())),
                          icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                          label: const Text("Add Another Exercise", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold))
                      ),
                    ] else ...[
                      _buildTextField(_descCtrl, "Description (e.g., 5km run at moderate pace)", TextInputType.multiline, maxLines: 3),
                    ],

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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, TextInputType type, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl, keyboardType: type, maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white),
      validator: (value) => value!.isEmpty ? "Required" : null,
    );
  }
}