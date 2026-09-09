import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  static Null get buildDir => null;

  static Null get name => null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriFit',
      theme: ThemeData(primarySwatch: Colors.green),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
