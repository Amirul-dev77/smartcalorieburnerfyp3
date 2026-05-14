import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import '../main.dart';
import '../providers/user_provider.dart';
import 'admin_dashboard_screen.dart'; // 👉 NEW: Import the admin dashboard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIN LOGIC ---
  Future<void> _handleLogin() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUserData();
      }

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScaffold()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();

      String errorMessage = "Login failed";
      if (e.code == 'user-not-found') errorMessage = "No user found for that email.";
      else if (e.code == 'wrong-password') errorMessage = "Wrong password provided.";
      else if (e.code == 'invalid-email') errorMessage = "The email address is badly formatted.";

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 👉 NEW: SECRET ADMIN DOOR
  void _showSecretAdminLogin() {
    TextEditingController passcodeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text("Admin Access"),
          ],
        ),
        content: TextField(
          controller: passcodeCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Enter Secret Passcode", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              // Secret passcode is 'admin123'
              if (passcodeCtrl.text == "admin123") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied."), backgroundColor: Colors.red));
              }
            },
            child: const Text("Enter"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 👉 NEW: Long Press the logo to trigger secret login!
              GestureDetector(
                onLongPress: _showSecretAdminLogin,
                child: const Icon(Icons.fitness_center, size: 80, color: Colors.deepPurple),
              ),

              const SizedBox(height: 20),
              const Text("Smart Calorie Burner", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Login to continue", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  child: const Text("Login", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: const Text("Register"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}