import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // --- 1. EDIT PROFILE LOGIC ---
  void _showEditDialog(BuildContext context, UserProvider userProvider) {
    // Initialize with current values
    final nameCtrl = TextEditingController(text: userProvider.name);
    final heightCtrl = TextEditingController(text: userProvider.height.toString());
    final weightCtrl = TextEditingController(text: userProvider.weight.toString());
    final neckCtrl = TextEditingController(text: userProvider.neck.toString());

    // Default waist/hip
    final waistCtrl = TextEditingController(text: userProvider.waist.toString());
    final hipCtrl = TextEditingController(text: userProvider.hip.toString());

    // Temp state
    String tempActivity = userProvider.activityLevel;
    String tempGender = userProvider.gender;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setState) {
              String waistLabel = (tempGender == 'male') ? "Abdomen (cm)" : "Waist (cm)";

              return AlertDialog(
                title: const Text("Edit Profile"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _editField("Display Name", nameCtrl),
                      const SizedBox(height: 10),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: tempGender,
                        decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                        items: ['male', 'female']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g.toUpperCase())))
                            .toList(),
                        onChanged: (val) {
                          setState(() => tempGender = val!);
                        },
                      ),
                      const SizedBox(height: 10),

                      Row(children: [
                        Expanded(child: _editField("Height (cm)", heightCtrl, isNum: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _editField("Weight (kg)", weightCtrl, isNum: true)),
                      ]),
                      const SizedBox(height: 10),

                      _editField("Neck (cm)", neckCtrl, isNum: true),
                      const SizedBox(height: 10),
                      _editField(waistLabel, waistCtrl, isNum: true),
                      const SizedBox(height: 10),

                      // Hip (Females Only)
                      if (tempGender == 'female') ...[
                        _editField("Hip (cm)", hipCtrl, isNum: true),
                        const SizedBox(height: 10),
                      ],

                      DropdownButtonFormField<String>(
                        value: tempActivity,
                        decoration: const InputDecoration(labelText: "Activity Level", border: OutlineInputBorder()),
                        items: ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active']
                            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (val) => tempActivity = val!,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        double h = double.tryParse(heightCtrl.text) ?? userProvider.height;
                        double w = double.tryParse(weightCtrl.text) ?? userProvider.weight;
                        double n = double.tryParse(neckCtrl.text) ?? userProvider.neck;
                        double waistVal = double.tryParse(waistCtrl.text) ?? userProvider.waist;
                        double hipVal = double.tryParse(hipCtrl.text) ?? userProvider.hip;

                        // Firebase Update
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance.collection('users').doc(uid).update({
                            'name': nameCtrl.text,
                            'gender': tempGender,
                            'height': h,
                            'weight': w,
                            'neck': n,
                            'waist': (tempGender == 'female') ? waistVal : 0,
                            'abdomen': (tempGender == 'male') ? waistVal : 0,
                            'hip': (tempGender == 'female') ? hipVal : 0,
                            'activityLevel': tempActivity,
                          });
                          await FirebaseAuth.instance.currentUser?.updateDisplayName(nameCtrl.text);
                        }

                        // Local Update
                        userProvider.name = nameCtrl.text;
                        userProvider.gender = tempGender;
                        userProvider.activityLevel = tempActivity;

                        userProvider.updateProfile(
                            w: w, h: h, n: n, waistVal: waistVal,
                            hipVal: (tempGender == 'female') ? hipVal : 0
                        );

                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));

                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    child: const Text("Save"),
                  )
                ],
              );
            }
        );
      },
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  // --- 2. LOGOUT LOGIC ---
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // --- 3. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    String waistLabel = (userProvider.gender == 'male') ? "Abdomen" : "Waist";

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        // Removed the pencil Icon from here!
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        child: Column(
          children: [
            // Avatar
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 15),

            // Name & Email
            Text(
                userProvider.name,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
            ),
            Text(
                user?.email ?? "",
                style: const TextStyle(color: Colors.grey, fontSize: 16)
            ),

            const SizedBox(height: 20),

            // --- NEW: CLEAR "EDIT PROFILE" BUTTON ---
            SizedBox(
              width: 160,
              height: 45,
              child: ElevatedButton(
                onPressed: () => _showEditDialog(context, userProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text("Edit Profile", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Details
            _sectionHeader("Personal Details"),
            _infoTile("Gender", userProvider.gender.toUpperCase()),
            _infoTile("Height", "${userProvider.height} cm"),
            _infoTile("Weight", "${userProvider.weight} kg"),
            const Divider(height: 40),

            _sectionHeader("Body Measurements"),
            _infoTile("Neck", "${userProvider.neck} cm"),
            _infoTile(waistLabel, "${userProvider.waist} cm"),
            if (userProvider.gender == 'female')
              _infoTile("Hip", "${userProvider.hip} cm"),

            const Divider(height: 40),

            _sectionHeader("Lifestyle"),
            _infoTile("Activity", userProvider.activityLevel),
            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)
        ),
      )
  );

  Widget _infoTile(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    ),
  );
}