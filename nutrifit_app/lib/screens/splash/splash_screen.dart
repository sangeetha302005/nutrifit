// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Screens
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required Null Function(bool p1) onThemeChanged});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _mainController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Setup Staggered Entrance Animations
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _logoScaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _textFadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
    ));

    _mainController.forward();

    // 2. Setup Background Pulse Animation (Heartbeat)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Start Initialization Process
    _initializeApp();
  }

  // --- LOGIC: SIMULATE LOADING & NAVIGATE ---
  Future<void> _initializeApp() async {
    // Simulate loading resources (progress bar)
    const totalSteps = 100;
    for (int i = 0; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        setState(() {
          _progressValue = i / totalSteps;
        });
      }
    }

    if (!mounted) return;

    // 🔥 CHANGED: Always navigate to Login Screen, regardless of Auth state
    Navigator.pushReplacement(
      context,
      _createRoute(const LoginScreen()),
    );
  }

  // Custom Fade Transition Route
  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 2. Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo with Pulse
                ScaleTransition(
                  scale: _pulseAnimation, // Subtle heartbeat
                  child: ScaleTransition(
                    scale: _logoScaleAnimation, // Entrance scale
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          'assets/logo.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Animated Text
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const Text(
                          "NutriFit",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 10)
                              ]
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your Health. Your Way.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Loading Indicator (Bottom)
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: FadeTransition(
              opacity: _textFadeAnimation,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${(_progressValue * 100).toInt()}%",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}