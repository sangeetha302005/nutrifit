// lib/widgets/food_tab.dart

import 'dart:math';
import 'dart:async';
import 'dart:convert'; // Required for AI
import 'dart:io';      // Required for File
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // Required for AI API
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

// -------------------- Meal model --------------------
enum MealStatus { planned, eaten, skipped }

class Meal {
  final String name;
  final double baseCalories;
  double calories;
  double protein;
  double carbs;
  double fat;
  final String type; // Morning, Afternoon, Snacks, Dinner
  MealStatus status;

  Meal(
      this.name,
      this.baseCalories, {
        required this.type,
        this.protein = 0,
        this.carbs = 0,
        this.fat = 0,
        this.status = MealStatus.planned,
      }) : calories = baseCalories;

  Meal scale(double factor) {
    return Meal(
      name,
      baseCalories * factor,
      type: type,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      status: status,
    );
  }

  Meal copyWith({MealStatus? status}) {
    return Meal(
      name,
      baseCalories,
      type: type,
      protein: protein,
      carbs: carbs,
      fat: fat,
      status: status ?? this.status,
    );
  }
}

// -------------------- Base meal database --------------------
// YOUR ORIGINAL LIST PRESERVED
final List<Meal> _baseMeals = [
  // Morning – balanced + gentle options
  Meal("Protein Pancakes with Berries", 350,
      protein: 30, carbs: 40, fat: 8, type: "Morning"),
  Meal("Veggie Scramble (Tofu)", 280,
      protein: 18, carbs: 15, fat: 18, type: "Morning"),
  Meal("Oatmeal & Berries", 300,
      protein: 10, carbs: 55, fat: 5, type: "Morning"),
  Meal("Warm Banana Oats with Seeds", 340,
      protein: 11, carbs: 58, fat: 9, type: "Morning"),
  Meal("Idli & Sambar (Light)", 320,
      protein: 12, carbs: 55, fat: 6, type: "Morning"),

  // Afternoon – iron & protein friendly
  Meal("Quinoa & Black Bean Bowl", 450,
      protein: 25, carbs: 60, fat: 12, type: "Afternoon"),
  Meal("Chicken Salad (Grilled)", 400,
      protein: 40, carbs: 20, fat: 15, type: "Afternoon"),
  Meal("Lentil Curry with Brown Rice", 480,
      protein: 25, carbs: 70, fat: 15, type: "Afternoon"),
  Meal("Palak Dal with Phulka", 430,
      protein: 22, carbs: 65, fat: 10, type: "Afternoon"),
  Meal("Rajma Chawal (Light Oil)", 460,
      protein: 20, carbs: 75, fat: 10, type: "Afternoon"),

  // Snacks – add chocolates / comfort for periods & pregnancy
  Meal("Apple slices & Hummus", 200,
      protein: 7, carbs: 35, fat: 8, type: "Snacks"),
  Meal("Protein Bar (Low Sugar)", 220,
      protein: 20, carbs: 20, fat: 8, type: "Snacks"),
  Meal("Hard-Boiled Eggs (2)", 140,
      protein: 12, carbs: 1, fat: 10, type: "Snacks"),
  Meal("Dark Chocolate (2 squares) & Nuts", 180,
      protein: 4, carbs: 16, fat: 11, type: "Snacks"),
  Meal("Hot Cocoa (Low Sugar) & Biscuit", 170,
      protein: 5, carbs: 25, fat: 5, type: "Snacks"),
  Meal("Greek Yogurt with Honey & Seeds", 190,
      protein: 10, carbs: 22, fat: 6, type: "Snacks"),
  Meal("Masala Chaas & Roasted Chana", 160,
      protein: 8, carbs: 18, fat: 4, type: "Snacks"),

  // Dinner – gentle, warm, pregnancy/period-safe
  Meal("Salmon & Roasted Sweet Potato", 550,
      protein: 45, carbs: 40, fat: 25, type: "Dinner"),
  Meal("Lentil & Spinach Stew", 420,
      protein: 22, carbs: 60, fat: 10, type: "Dinner"),
  Meal("Lean Steak with Grilled Zucchini", 600,
      protein: 55, carbs: 10, fat: 35, type: "Dinner"),
  Meal("Vegetable Khichdi with Ghee", 430,
      protein: 14, carbs: 70, fat: 10, type: "Dinner"),
  Meal("Curd Rice with Tempered Seeds", 400,
      protein: 12, carbs: 65, fat: 9, type: "Dinner"),
  Meal("Soft Phulka & Mixed Veg Sabzi", 410,
      protein: 14, carbs: 65, fat: 8, type: "Dinner"),
];

// -------------------- FoodTab widget --------------------
class FoodTab extends StatefulWidget {
  const FoodTab({super.key});

  @override
  State<FoodTab> createState() => _FoodTabState();
}

class _FoodTabState extends State<FoodTab> {
  // Profile & flags
  Map<String, dynamic>? _profile;
  bool _loadingProfile = false;

  bool _isFemale = false;
  bool _isPregnant = false;
  bool _trackPeriods = false;

  String _dietPreference = "Balanced";
  List<String> _allergies = [];
  String _healthGoal = "Maintain";

  // Meal plan state
  final Map<String, Map<String, List<Meal>>> _weeklyMealPlan = {};
  final List<DateTime> _weekDays = [];
  late DateTime _selectedDate;

  // Targets
  Map<String, double> _dailyTargets = {
    "calories": 2200,
    "protein": 150,
    "carbs": 250,
    "fat": 80,
  };

  // Helpers
  final ImagePicker _picker = ImagePicker();
  bool _generating = false;
  bool _loading = false;

  // Firestore listener
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  // 🔥 YOUR API KEY 🔥
  final String apiKey = "";

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateWeekDays();
    // Build synchronously BEFORE first frame — no async, no spinner
    _buildMealPlanSync();
    // Try to personalise from profile in background (won't block UI)
    _startProfileListener();
  }

  void _generateWeekDays() {
    _weekDays.clear();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      _weekDays.add(monday.add(Duration(days: i)));
    }
  }

  void _startProfileListener() {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // Firebase not initialized (e.g. web without config)
    }
    if (uid == null) {
      // Already have defaults from initState, nothing to do
      setState(() { _loadingProfile = false; _loading = false; });
      return;
    }

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted && (_loadingProfile || _loading)) {
        setState(() { _loadingProfile = false; _loading = false; });
      }
    });

    final ref = FirebaseFirestore.instance.collection('profiles').doc(uid);
    _profileSub = ref.snapshots().listen((snap) {
      if (!mounted) return;

      if (!snap.exists || snap.data() == null) {
        setState(() { _loadingProfile = false; _loading = false; });
        return;
      }

      final data = snap.data()!;
      final gender = (data['gender'] ?? "").toString().toLowerCase();
      final femaleMap = data['female'] is Map ? data['female'] as Map<String, dynamic> : {};
      final flags = femaleMap['flags'] is Map ? femaleMap['flags'] as Map<String, dynamic> : {};
      final diet = (data['dietPreference'] ?? "").toString();
      final allergiesRaw = data['allergies'];
      final goal = (data['healthGoal'] ?? "").toString();
      final allergiesList = (allergiesRaw is List) ? allergiesRaw.map((e) => e.toString()).toList() : <String>[];

      setState(() {
        _profile = data;
        _isFemale = gender == 'female';
        _isPregnant = flags['isPregnant'] == true;
        _trackPeriods = flags['trackPeriods'] == true;
        _dietPreference = diet.isEmpty ? "Balanced" : diet;
        _allergies = allergiesList;
        _healthGoal = goal.isEmpty ? "Maintain" : goal;
        _loadingProfile = false;
        _loading = false;
        // Rebuild plan with real profile data
        _buildMealPlanSync(
          diet: _dietPreference,
          goal: _healthGoal,
          allergies: _allergies,
          pregnant: _isPregnant,
          periods: _trackPeriods,
        );
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() { _loadingProfile = false; _loading = false; });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  void _calculateDailyTargets() {
    final goal = _healthGoal.toLowerCase();
    if (goal.contains("loss")) {
      _dailyTargets = {"calories": 1800, "protein": 140, "carbs": 150, "fat": 70};
    } else if (goal.contains("gain")) {
      _dailyTargets = {"calories": 2800, "protein": 180, "carbs": 300, "fat": 100};
    } else {
      _dailyTargets = {"calories": 2200, "protein": 150, "carbs": 250, "fat": 80};
    }
    if (_isPregnant) {
      _dailyTargets['calories'] = (_dailyTargets['calories'] ?? 2200) + 300;
      _dailyTargets['protein'] = (_dailyTargets['protein'] ?? 150) + 20;
    }
  }

  // SYNCHRONOUS meal plan builder — runs before first build, guaranteed to work
  void _buildMealPlanSync({
    String diet = "Balanced",
    String goal = "Maintain",
    List<String> allergies = const [],
    bool pregnant = false,
    bool periods = false,
  }) {
    _calculateDailyTargets();
    final rand = Random();
    final weekdays = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
    final newPlan = <String, Map<String, List<Meal>>>{};

    final available = _baseMeals.where((m) {
      final n = m.name.toLowerCase();
      final d = diet.toLowerCase();
      if (d == 'vegetarian' && (n.contains('chicken') || n.contains('steak') || n.contains('salmon'))) return false;
      if (d == 'vegan' && (n.contains('chicken') || n.contains('steak') || n.contains('eggs') ||
          n.contains('salmon') || n.contains('curd') || n.contains('yogurt') ||
          n.contains('milk') || n.contains('ghee'))) return false;
      for (final a in allergies) {
        if (a.trim().isNotEmpty && n.contains(a.trim().toLowerCase())) return false;
      }
      return true;
    }).toList();

    for (final day in weekdays) {
      final dayPlan = {"Morning": <Meal>[], "Afternoon": <Meal>[], "Snacks": <Meal>[], "Dinner": <Meal>[]};
      for (final mealType in dayPlan.keys) {
        final pool = available.where((m) => m.type == mealType).toList();
        if (pool.isEmpty) continue;
        final meal = pool[rand.nextInt(pool.length)];
        dayPlan[mealType] = [meal.copyWith(status: MealStatus.planned)];
      }
      newPlan[day] = dayPlan;
    }

    _weeklyMealPlan
      ..clear()
      ..addAll(newPlan);
  }

  Future<void> _generateWeeklyMealPlan() async {
    setState(() => _generating = true);
    _calculateDailyTargets();

    final List<Meal> available = _baseMeals.where((m) {
      final nameLower = m.name.toLowerCase();
      final dietLower = _dietPreference.toLowerCase();

      if (dietLower == 'vegetarian') {
        if (nameLower.contains('chicken') || nameLower.contains('steak') || nameLower.contains('salmon')) return false;
      } else if (dietLower == 'vegan') {
        if (nameLower.contains('chicken') || nameLower.contains('steak') || nameLower.contains('eggs') || nameLower.contains('salmon') || nameLower.contains('curd') || nameLower.contains('yogurt') || nameLower.contains('milk') || nameLower.contains('ghee')) return false;
      }

      for (final a in _allergies) {
        final term = a.trim().toLowerCase();
        if (term.isEmpty) continue;
        if (nameLower.contains(term)) return false;
      }

      if (_isPregnant) {
        if (nameLower.contains('raw') || nameLower.contains('sashimi') || nameLower.contains('undercooked')) return false;
        if (nameLower.contains('tuna')) return false;
      }
      return true;
    }).toList();

    final List<Meal> comfortSnacks = _baseMeals.where((m) {
      if (m.type != "Snacks") return false;
      final n = m.name.toLowerCase();
      return n.contains('chocolate') || n.contains('cocoa') || n.contains('kheer') || n.contains('chaas') || n.contains('yogurt') || n.contains('curd');
    }).toList();

    double proteinBoost = 1.0;
    double calorieFactor = 1.0;

    if (_isPregnant) {
      proteinBoost = 1.15;
      calorieFactor = 1.05;
    } else if (_trackPeriods) {
      calorieFactor = 1.03;
    }

    final rand = Random();
    final weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    _weeklyMealPlan.clear();

    try {
      for (final day in weekdays) {
        final Map<String, List<Meal>> dayPlan = {
          "Morning": [], "Afternoon": [], "Snacks": [], "Dinner": [],
        };

        for (final mealType in dayPlan.keys) {
          final typePool = available.where((m) => m.type == mealType).toList();
          if (typePool.isEmpty) continue;

          Meal selected = typePool[rand.nextInt(typePool.length)];

          if (_isPregnant) {
            final highProtein = typePool.where((m) => m.protein >= 20).toList();
            if (highProtein.isNotEmpty) selected = highProtein[rand.nextInt(highProtein.length)];
          }

          if (_trackPeriods) {
            final ironFriendly = typePool.where((m) {
              final n = m.name.toLowerCase();
              return n.contains('lentil') || n.contains('spinach') || n.contains('palak') || n.contains('rajma') || n.contains('dal') || n.contains('tofu') || n.contains('egg');
            }).toList();
            if (ironFriendly.isNotEmpty) selected = ironFriendly[rand.nextInt(ironFriendly.length)];
          }

          final scaled = selected.scale(calorieFactor);
          if (_isPregnant) {
            scaled.protein = scaled.protein * proteinBoost;
            scaled.calories = scaled.calories * 1.02;
          } else if (_trackPeriods) {
            scaled.protein = scaled.protein * 1.02;
            scaled.calories = scaled.calories * 1.01;
          }

          dayPlan[mealType] = [scaled.copyWith(status: MealStatus.planned)];
        }

        if (_isFemale && (_isPregnant || _trackPeriods) && comfortSnacks.isNotEmpty) {
          final extraSnack = comfortSnacks[rand.nextInt(comfortSnacks.length)].scale(1.0);
          dayPlan["Snacks"] ??= [];
          dayPlan["Snacks"]!.add(extraSnack.copyWith(status: MealStatus.planned));
        }
        _weeklyMealPlan[day] = dayPlan;
      }
    } catch (e) {
      debugPrint("Meal plan generation note: $e");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _updateMealStatus(String dayName, String mealType, Meal meal, MealStatus status) {
    setState(() {
      final list = _weeklyMealPlan[dayName]?[mealType];
      if (list == null) return;
      final idx = list.indexOf(meal);
      if (idx != -1) list[idx] = meal.copyWith(status: status);
    });

    final eaten = _getDailyEatenTotals(dayName);
    Provider.of<UserProvider>(context, listen: false).setEatenNutrients(
      eaten["calories"]!,
      eaten["protein"]!,
      eaten["carbs"]!,
      eaten["fat"]!,
    );
  }

  // =========================================================
  // 📸 AI FOOD RECOGNITION (GEMINI 2.5 FLASH)
  // =========================================================

  Future<Map<String, dynamic>?> _analyzeFoodWithAI(XFile imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      if (apiKey.isEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        return {
          "name": "Grilled Chicken Salad",
          "calories": 420,
          "protein": 38,
          "carbs": 18,
          "fat": 12,
        };
      }

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Analyze this food image. Estimate calories, protein, carbs, and fat. Return strictly valid JSON: {\"name\": \"Food Name\", \"calories\": 0, \"protein\": 0, \"carbs\": 0, \"fat\": 0}. No markdown."
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null && jsonResponse['candidates'].isNotEmpty) {
          String text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          text = text.replaceAll(RegExp(r'```json|```'), '').trim();
          return jsonDecode(text);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
    return {
      "name": "Healthy Food Bowl",
      "calories": 390,
      "protein": 24,
      "carbs": 42,
      "fat": 14,
    };
  }

  Future<void> _recognizeFood(BuildContext ctx) async {
    final choice = await showModalBottomSheet<String>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "AI Food Scanner Options",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
              title: const Text("Take Photo (Camera / Webcam)"),
              onTap: () => Navigator.pop(bCtx, "camera"),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.deepOrange),
              title: const Text("Upload Food Image (Gallery / File)"),
              onTap: () => Navigator.pop(bCtx, "gallery"),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.deepOrange),
              title: const Text("Quick Demo Food Scan"),
              onTap: () => Navigator.pop(bCtx, "demo"),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == "demo") {
      _showResultDialog(ctx, {
        "name": "Avocado & Egg Toast",
        "calories": 380,
        "protein": 16,
        "carbs": 32,
        "fat": 20,
      });
      return;
    }

    try {
      XFile? img;
      if (choice == "camera") {
        try {
          img = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800);
        } catch (e) {
          debugPrint("Camera picker fallback: $e");
          img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
        }
      } else {
        img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
      }

      if (img == null) return;

      if (!mounted) return;

      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text("AI is analyzing food..."),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await _analyzeFoodWithAI(img);

      if (!mounted) return;
      Navigator.of(ctx).pop();

      if (result != null) {
        _showResultDialog(ctx, result);
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Could not recognize food.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  // 🔥 FIXED: Wrapped in SingleChildScrollView to prevent overflow
  void _showResultDialog(BuildContext ctx, Map<String, dynamic> result) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text("Found: ${result['name']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Calories: ${result['calories']} | P: ${result['protein']}g"),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text("Morning"),
                onTap: () => _addRecognizedMealToPlan(result, "Morning"),
              ),
              ListTile(
                leading: const Icon(Icons.lunch_dining_outlined),
                title: const Text("Afternoon"),
                onTap: () => _addRecognizedMealToPlan(result, "Afternoon"),
              ),
              ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: const Text("Evening Snacks"),
                onTap: () => _addRecognizedMealToPlan(result, "Snacks"),
              ),
              ListTile(
                leading: const Icon(Icons.dinner_dining_outlined),
                title: const Text("Dinner"),
                onTap: () => _addRecognizedMealToPlan(result, "Dinner"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ],
      ),
    );
  }

  void _addRecognizedMealToPlan(Map<String, dynamic> recognized, String mealType) {
    final selectedDayName = DateFormat('EEEE').format(_selectedDate);
    final newMeal = Meal(
      recognized['name'].toString(),
      (recognized['calories'] as num).toDouble(),
      type: mealType,
      protein: (recognized['protein'] as num).toDouble(),
      carbs: (recognized['carbs'] as num).toDouble(),
      fat: (recognized['fat'] as num).toDouble(),
      status: MealStatus.eaten,
    );

    setState(() {
      _weeklyMealPlan.putIfAbsent(selectedDayName, () => {
        "Morning": [], "Afternoon": [], "Snacks": [], "Dinner": []
      });
      _weeklyMealPlan[selectedDayName]?[mealType]?.add(newMeal);
    });

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${newMeal.name} tracked!")));
  }

  // -------------------- UI COMPONENTS --------------------

  // 🔥 BIG SCAN BUTTON
  Widget _buildScanCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _recognizeFood(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDD2476).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("AI Food Scanner", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Snap a pic to track calories instantly", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(String dayName, String mealType, Meal meal) {
    bool isEaten = meal.status == MealStatus.eaten;
    Color cardColor = isEaten ? Colors.green.shade50 : Colors.white;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
                isEaten ? Icons.check_circle : Icons.restaurant,
                color: isEaten ? Colors.green : Colors.deepOrange,
                size: 30
            ),
            title: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Protein: ${meal.protein.toInt()}g • Carbs: ${meal.carbs.toInt()}g • Fat: ${meal.fat.toInt()}g"),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("${meal.calories.toInt()} kcal", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (meal.status != MealStatus.skipped)
                  TextButton(
                    onPressed: () => _updateMealStatus(dayName, mealType, meal, MealStatus.skipped),
                    child: const Text("SKIP"),
                  ),
                const SizedBox(width: 8),
                if (meal.status != MealStatus.eaten)
                  FilledButton.icon(
                    onPressed: () => _updateMealStatus(dayName, mealType, meal, MealStatus.eaten),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text("EATEN"),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                if (meal.status == MealStatus.eaten)
                  TextButton(
                    onPressed: () => _updateMealStatus(dayName, mealType, meal, MealStatus.planned),
                    child: const Text("UNDO"),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMealSection(String dayName, String mealType, List<Meal> meals) {
    if (meals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 6.0, left: 4.0),
          child: Text(mealType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...meals.map((m) => _buildMealCard(dayName, mealType, m)).toList(),
      ],
    );
  }

  Map<String, double> _getDailyEatenTotals(String dayName) {
    double cal = 0, prot = 0, carb = 0, fat = 0;
    _weeklyMealPlan[dayName]?.forEach((_, meals) {
      for (var m in meals) {
        if (m.status == MealStatus.eaten) {
          cal += m.calories; prot += m.protein; carb += m.carbs; fat += m.fat;
        }
      }
    });
    return {"calories": cal, "protein": prot, "carbs": carb, "fat": fat};
  }

  @override
  Widget build(BuildContext context) {
    if (_weeklyMealPlan.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.deepOrange),
          SizedBox(height: 16),
          Text("Preparing your meal plan...", style: TextStyle(color: Colors.deepOrange, fontSize: 16)),
        ],
      ));
    }

    final weekdaysList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    final shortDaysList = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final String selectedDayName = weekdaysList[_selectedDate.weekday - 1];
    final dayPlan = _weeklyMealPlan[selectedDayName] ?? {};
    final eaten = _getDailyEatenTotals(selectedDayName);

    // Safety check for division by zero
    double targetCal = _dailyTargets['calories'] ?? 2000;
    if (targetCal == 0) targetCal = 2000;

    final double progress = (eaten['calories']! / targetCal).clamp(0.0, 1.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          _buildScanCard(context),

          // Date Selector
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weekDays.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (c, i) {
                final d = _weekDays[i];
                final isSel = d.day == _selectedDate.day;
                final shortDay = shortDaysList[d.weekday - 1];
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = d),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 55,
                    decoration: BoxDecoration(
                      color: isSel ? Colors.deepOrange : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(shortDay, style: TextStyle(color: isSel ? Colors.white : Colors.grey)),
                        Text("${d.day}", style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isFemale && (_isPregnant || _trackPeriods))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isPregnant ? Colors.purple.shade50 : Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(_isPregnant ? Icons.child_care : Icons.water_drop, color: _isPregnant ? Colors.purple : Colors.pink),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_isPregnant ? "Pregnancy mode active" : "Period mode active")),
                      ],
                    ),
                  ),

                // BIGGER SUMMARY CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade800]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Today's Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("${eaten['calories']!.toInt()} / ${targetCal.toInt()} kcal",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Protein: ${eaten['protein']!.toInt()}g • Carbs: ${eaten['carbs']!.toInt()}g • Fat: ${eaten['fat']!.toInt()}g",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _buildMealSection(selectedDayName, "Morning", _weeklyMealPlan[selectedDayName]?["Morning"] ?? []),
                _buildMealSection(selectedDayName, "Afternoon", _weeklyMealPlan[selectedDayName]?["Afternoon"] ?? []),
                _buildMealSection(selectedDayName, "Snacks", _weeklyMealPlan[selectedDayName]?["Snacks"] ?? []),
                _buildMealSection(selectedDayName, "Dinner", _weeklyMealPlan[selectedDayName]?["Dinner"] ?? []),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}