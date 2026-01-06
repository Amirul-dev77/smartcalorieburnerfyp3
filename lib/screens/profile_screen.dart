import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    String waistLabel = (userProvider.gender == 'male') ? "Abdomen" : "Waist";

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        child: Column(
          children: [
            // --- HEADER ---
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 15),

            // Name
            Text(
                userProvider.name,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
            ),

            // Email
            Text(
                user?.email ?? "",
                style: const TextStyle(color: Colors.grey, fontSize: 16)
            ),
            const SizedBox(height: 40),

            // --- SECTIONS ---
            _sectionHeader("Personal Details"),
            _infoTile("Gender", userProvider.gender.toUpperCase()),
            _infoTile("Height", "${userProvider.height} cm"),
            _infoTile("Weight", "${userProvider.weight} kg"),
            const Divider(height: 40),

            _sectionHeader("Body Measurements"),
            _infoTile("Neck", "${userProvider.neck} cm"),
            _infoTile(waistLabel, "${userProvider.waist} cm"),
            if (userProvider.gender == 'female') _infoTile("Hip", "${userProvider.hip} cm"),
            const Divider(height: 40),

            _sectionHeader("Lifestyle"),
            _infoTile("Activity", userProvider.activityLevel),
            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
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

  // Header Style (Purple Titles)
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

  // Data Row Style - BALANCED SIZE
  Widget _infoTile(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0), // Nice spacing
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LABEL (Left side)
        Text(
            title,
            style: const TextStyle(
                fontSize: 18,            // Increased size to match data
                fontWeight: FontWeight.w500, // Medium weight
                color: Colors.black87    // Darker grey/black
            )
        ),
        // DATA (Right side)
        Text(
            value,
            style: const TextStyle(
                fontSize: 18,            // Reduced from 22 to match label
                fontWeight: FontWeight.bold,
                color: Colors.black      // Solid black
            )
        ),
      ],
    ),
  );
}