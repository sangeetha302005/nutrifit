import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import '../dashboard/dashboard_screen.dart'; // Adjust path if needed

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  bool _loading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _agreedToTerms = false;

  // Animations
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  void signupUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please agree to the Terms & Conditions"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(username);
    } catch (e) {
      debugPrint("Firebase signup note: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: username.isNotEmpty ? username : 'User',
            gender: '',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient Background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade900],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // --- HEADER ---
                    Hero(
                      tag: "app_logo",
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))
                            ]
                        ),
                        child: Image.asset("assets/logo.png", height: 70, width: 70),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Join NutriFit",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Create an account to start your journey",
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 30),

                    // --- FORM CARD ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Username
                            TextFormField(
                              controller: _usernameController,
                              decoration: _inputDecoration("Username", Icons.person_outline),
                              validator: (value) => value!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 16),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration("Email", Icons.email_outlined),
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Required";
                                if (!value.contains('@')) return "Invalid email";
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: _inputDecoration("Password", Icons.lock_outline).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              validator: (value) => value!.length < 6 ? "Min 6 characters" : null,
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmVisible,
                              decoration: _inputDecoration("Confirm Password", Icons.lock_reset).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_isConfirmVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                  onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) return "Passwords do not match";
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Terms Checkbox
                            Row(
                              children: [
                                SizedBox(
                                  height: 24, width: 24,
                                  child: Checkbox(
                                    value: _agreedToTerms,
                                    activeColor: Colors.deepOrange,
                                    onChanged: (v) => setState(() => _agreedToTerms = v!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text("I agree to the Terms & Privacy Policy", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _loading ? null : signupUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 5,
                                  shadowColor: Colors.deepOrange.withOpacity(0.4),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("SIGN UP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- SOCIAL SIGNUP ---
                    const Text("Or sign up with", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton("assets/google.png"),
                        const SizedBox(width: 20),
                        _socialButton("assets/apple.png"),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- LOGIN LINK ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text("Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: Colors.deepOrange),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.deepOrange, width: 1.5)),
    );
  }

  Widget _socialButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Image.asset(assetPath, height: 24, width: 24, errorBuilder: (c,o,s) => const Icon(Icons.login, color: Colors.deepOrange)),
    );
  }
}