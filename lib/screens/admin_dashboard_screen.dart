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

  // Cardio Specific Customizations
  bool _showSpeed = true;
  final TextEditingController _startButtonTextCtrl = TextEditingController();

  String _selectedType = 'strength';

  // Smart Match Tags
  final List<String> _lifestyleOptions = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
  final List<String> _bmiOptions = ['Underweight', 'Normal', 'Overweight', 'Obese'];

  final List<String> _selectedLifestyles = [];
  final List<String> _selectedBmis = [];

  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _calCtrl.dispose(); _durCtrl.dispose();
    _startButtonTextCtrl.dispose();
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
      final Map<String, dynamic> routineData = {
        'title': _titleCtrl.text.trim(),
        'type': _selectedType,
        'desc': finalDesc,
        'exercises': exercisesList,
        'calories': int.parse(_calCtrl.text.trim()),
        'duration': '${_durCtrl.text.trim()} mins',
        'lifestyle': _selectedLifestyles,
        'bmi': _selectedBmis,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (_selectedType == 'cardio') {
        routineData['show_speed'] = _showSpeed;
        routineData['start_button_text'] = _startButtonTextCtrl.text.trim();
      }

      await FirebaseFirestore.instance.collection('routines').add(routineData);

      // Clear the form
      _titleCtrl.clear(); _descCtrl.clear(); _durCtrl.clear(); _calCtrl.clear(); _startButtonTextCtrl.clear();
      setState(() {
        _selectedLifestyles.clear(); _selectedBmis.clear();
        _exerciseCtrls = [TextEditingController()];
        _showSpeed = true;
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

  Future<void> _resetToDefault() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset to Defaults?"),
        content: const Text(
          "Are you sure? This will delete all custom routines and restore the 5 original default workouts."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reset"),
          )
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      // 1. Get all routines in the routines collection
      final snapshot = await firestore.collection('routines').get();
      
      // 2. Perform deletion in batches
      final deleteBatch = firestore.batch();
      for (var doc in snapshot.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();

      // 3. Batch seed the original 5 default workouts
      final seedBatch = firestore.batch();
      final collection = firestore.collection('routines');

      final List<Map<String, dynamic>> routinesToSeed = [
        {
          'title': 'Push Workout',
          'type': 'strength',
          'desc': 'Bench Press, Shoulder Press, Lateral Raises, Tricep Dips',
          'exercises': ['Bench Press', 'Shoulder Press', 'Lateral Raises', 'Tricep Dips'],
          'calories': 250,
          'duration': '45 mins',
          'lifestyle': ['Moderate', 'Active', 'Very Active'],
          'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
          'created_at': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Pull Workout',
          'type': 'strength',
          'desc': 'Plate-Loaded Rows, Lat Pulldowns, Face Pulls, Bayesian Curls',
          'exercises': ['Plate-Loaded Rows', 'Lat Pulldowns', 'Face Pulls', 'Bayesian Curls'],
          'calories': 230,
          'duration': '45 mins',
          'lifestyle': ['Moderate', 'Active', 'Very Active'],
          'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
          'created_at': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Legs Workout',
          'type': 'strength',
          'desc': 'Squats, Leg Press, RDLs, Calf Raises',
          'exercises': ['Squats', 'Leg Press', 'RDLs', 'Calf Raises'],
          'calories': 350,
          'duration': '50 mins',
          'lifestyle': ['Moderate', 'Active', 'Very Active'],
          'bmi': ['Underweight', 'Normal', 'Overweight', 'Obese'],
          'created_at': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Outdoor Running',
          'type': 'cardio',
          'desc': '5km run at a moderate pace (approx 6:00/km)',
          'calories': 400,
          'duration': '30 mins',
          'lifestyle': ['Active', 'Very Active'],
          'bmi': ['Normal', 'Underweight'],
          'show_speed': true,
          'start_button_text': 'START RUN',
          'created_at': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Brisk Walking',
          'type': 'cardio',
          'desc': 'Power walking in the park or treadmill incline',
          'calories': 150,
          'duration': '30 mins',
          'lifestyle': ['Sedentary', 'Light', 'Moderate'],
          'bmi': ['Overweight', 'Obese', 'Normal', 'Underweight'],
          'show_speed': true,
          'start_button_text': 'START WALK',
          'created_at': FieldValue.serverTimestamp(),
        },
      ];

      for (var routine in routinesToSeed) {
        seedBatch.set(collection.doc(), routine);
      }
      await seedBatch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All routines successfully reset to original defaults!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to reset: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> routine) {
    final docId = routine['id'];

    // Controllers
    final TextEditingController editTitleCtrl = TextEditingController(text: routine['title']);
    
    // Parse duration number
    String rawDuration = routine['duration'] ?? '';
    String cleanDuration = rawDuration.replaceAll(RegExp(r'[^0-9]'), '');
    final TextEditingController editDurCtrl = TextEditingController(text: cleanDuration);
    
    final TextEditingController editCalCtrl = TextEditingController(text: (routine['calories'] ?? '').toString());
    
    // Type
    String editType = routine['type'] ?? 'strength';

    // Strength exercises
    List<TextEditingController> editExerciseCtrls = [];
    if (editType == 'strength') {
      List<dynamic> exercises = routine['exercises'] ?? [];
      if (exercises.isNotEmpty) {
        editExerciseCtrls = exercises.map((e) => TextEditingController(text: e.toString())).toList();
      } else {
        // Fallback: split desc if exercises list is empty
        String desc = routine['desc'] ?? '';
        List<String> splitList = desc.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        editExerciseCtrls = splitList.map((e) => TextEditingController(text: e)).toList();
      }
    } else {
      editExerciseCtrls = [TextEditingController()];
    }

    // Cardio description, speed, button text
    final TextEditingController editDescCtrl = TextEditingController(
      text: editType == 'cardio' ? routine['desc'] : ''
    );
    bool editShowSpeed = routine['show_speed'] ?? true;
    final TextEditingController editStartBtnTextCtrl = TextEditingController(
      text: editType == 'cardio' ? (routine['start_button_text'] ?? '') : ''
    );

    // Tags
    final List<String> editSelectedLifestyles = List<String>.from(routine['lifestyle'] ?? []);
    final List<String> editSelectedBmis = List<String>.from(routine['bmi'] ?? []);

    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Expanded(
                    child: Text("Edit Workout Routine", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  )
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Form(
                    key: dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: editTitleCtrl,
                          decoration: InputDecoration(labelText: "Routine Title", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          validator: (value) => value!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: editType,
                          decoration: InputDecoration(labelText: "Workout Type", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: const [
                            DropdownMenuItem(value: 'strength', child: Text("Strength (Weights/Reps)")),
                            DropdownMenuItem(value: 'cardio', child: Text("Cardio (Distance/Time)")),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              editType = val!;
                              if (editType == 'strength' && editExerciseCtrls.isEmpty) {
                                editExerciseCtrls = [TextEditingController()];
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),

                        // Dynamic strength or cardio inputs
                        if (editType == 'strength') ...[
                          const Text("Exercises in this routine:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...List.generate(editExerciseCtrls.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: editExerciseCtrls[index],
                                      decoration: InputDecoration(labelText: "Exercise ${index + 1}", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                      validator: (value) => value!.isEmpty ? "Required" : null,
                                    ),
                                  ),
                                  if (editExerciseCtrls.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                                      onPressed: () {
                                        setDialogState(() {
                                          editExerciseCtrls.removeAt(index);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                editExerciseCtrls.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                            label: const Text("Add Another Exercise", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: editDescCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(labelText: "Description", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (value) => value!.isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 15),
                          SwitchListTile(
                            title: const Text("Show Speed Display", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: const Text("Hide speed for user running/walking screen", style: TextStyle(fontSize: 12)),
                            value: editShowSpeed,
                            activeColor: Colors.deepPurple,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setDialogState(() {
                                editShowSpeed = val;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: editStartBtnTextCtrl,
                            decoration: InputDecoration(
                              labelText: "Start Button Text (e.g. START JOG)",
                              hintText: "Defaults to 'START RUN/WALK'",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: editDurCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: "Mins", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                validator: (value) => value!.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextFormField(
                                controller: editCalCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: "Kcal Burn", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                validator: (value) => value!.isEmpty ? "Required" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text("Target Lifestyles:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 6,
                          children: _lifestyleOptions.map((life) {
                            return FilterChip(
                              label: Text(life, style: const TextStyle(fontSize: 11)),
                              selected: editSelectedLifestyles.contains(life),
                              selectedColor: Colors.deepPurple.withOpacity(0.2),
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if (selected) {
                                    editSelectedLifestyles.add(life);
                                  } else {
                                    editSelectedLifestyles.remove(life);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        const Text("Target BMIs:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 6,
                          children: _bmiOptions.map((bmi) {
                            return FilterChip(
                              label: Text(bmi, style: const TextStyle(fontSize: 11)),
                              selected: editSelectedBmis.contains(bmi),
                              selectedColor: Colors.blue.withOpacity(0.2),
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if (selected) {
                                    editSelectedBmis.add(bmi);
                                  } else {
                                    editSelectedBmis.remove(bmi);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (!dialogFormKey.currentState!.validate()) return;
                    if (editSelectedLifestyles.isEmpty || editSelectedBmis.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Select at least one Lifestyle and BMI tag!"), backgroundColor: Colors.orange)
                      );
                      return;
                    }

                    List<String> exercisesList = [];
                    String finalDesc = editDescCtrl.text.trim();

                    if (editType == 'strength') {
                      exercisesList = editExerciseCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                      finalDesc = exercisesList.join(', ');
                    }

                    try {
                      final Map<String, dynamic> updateData = {
                        'title': editTitleCtrl.text.trim(),
                        'type': editType,
                        'desc': finalDesc,
                        'exercises': exercisesList,
                        'calories': int.parse(editCalCtrl.text.trim()),
                        'duration': '${editDurCtrl.text.trim()} mins',
                        'lifestyle': editSelectedLifestyles,
                        'bmi': editSelectedBmis,
                      };

                      if (editType == 'cardio') {
                        updateData['show_speed'] = editShowSpeed;
                        updateData['start_button_text'] = editStartBtnTextCtrl.text.trim();
                      } else {
                        updateData['show_speed'] = FieldValue.delete();
                        updateData['start_button_text'] = FieldValue.delete();
                      }

                      await FirebaseFirestore.instance.collection('routines').doc(docId).update(updateData);
                      
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Routine updated successfully!"), backgroundColor: Colors.green)
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
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
              Tab(icon: Icon(Icons.list), text: "Manage Routines"),
              Tab(icon: Icon(Icons.add_box), text: "Add Routine"),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
              children: [
                // TAB 1 (MANAGE ROUTINES): Dynamic routines drawn exclusively from Firestore
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('routines').orderBy('created_at', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Map<String, dynamic>> allRoutines = [];
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      allRoutines = snapshot.data!.docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return data;
                      }).toList();
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${allRoutines.length} Active Routines",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                              ),
                              OutlinedButton.icon(
                                onPressed: _resetToDefault,
                                icon: const Icon(Icons.restore, color: Colors.redAccent),
                                label: const Text("Reset to Default", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: allRoutines.isEmpty
                            ? const Center(child: Text("No routines in Firestore. Click 'Reset to Default' or add one!"))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: allRoutines.length,
                                itemBuilder: (context, index) {
                                  var data = allRoutines[index];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(color: Colors.deepPurple.withOpacity(0.3))
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.deepPurple.withOpacity(0.1),
                                        child: Icon(
                                          data['type'] == 'cardio' ? Icons.directions_run : Icons.fitness_center, 
                                          color: Colors.deepPurple
                                        ),
                                      ),
                                      title: Text(data['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text("${data['calories']} kcal • ${data['duration']}"),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => _showEditDialog(context, data),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteRoutine(data['id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                    );
                  }
                ),

                // TAB 2 (ADD ROUTINE): Dynamic Creation Form
                SingleChildScrollView(
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
                          const SizedBox(height: 15),
                          SwitchListTile(
                            title: const Text("Show Speed Display", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: const Text("Toggle whether the user sees live speed stats", style: TextStyle(fontSize: 12)),
                            value: _showSpeed,
                            activeColor: Colors.deepPurple,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _showSpeed = val),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _startButtonTextCtrl,
                            decoration: InputDecoration(
                              labelText: "Start Button Text (e.g. START WALK)",
                              hintText: "Defaults to 'START RUN/WALK'",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              filled: true,
                              fillColor: Colors.white
                            ),
                          ),
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