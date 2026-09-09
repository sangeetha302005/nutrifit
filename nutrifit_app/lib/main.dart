import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nutrifit_app/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:nutrifit_app/screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Skip Firebase init on web when no firebase_options are configured
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init warning: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const NutriFitApp(),
    ),
  );
}

class NutriFitApp extends StatelessWidget {
  const NutriFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NutriFit',
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.deepOrange,
            scaffoldBackgroundColor: Colors.grey.shade50,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: Colors.deepOrange,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          themeMode: mode,
          home: SplashScreen(onThemeChanged: (bool p1) {}),
        );
      },
    );
  }
}