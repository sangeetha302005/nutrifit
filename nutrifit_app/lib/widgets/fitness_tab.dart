// lib/widgets/fitness_tab.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutrifit_app/widgets/workout_session_screen.dart';
// Ensure this import matches your file structure
import '../screens/workout_session_screen.dart';

class FitnessTab extends StatefulWidget {
  const FitnessTab({super.key});

  @override
  State<FitnessTab> createState() => _FitnessTabState();
}

class _FitnessTabState extends State<FitnessTab>
    with SingleTickerProviderStateMixin {
  // Inputs
  double durationMinutes = 45;
  String equipment = "Bodyweight";
  String intensity = "Moderate";
  List<String> targetAreas = ["Full Body"];

  // State
  Map<String, dynamic>? profileData;
  bool loadingProfile = true;
  bool generating = false;
  bool _isFemale = false;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Generated Data
  WorkoutDay? generatedPlan;

  // Constants
  final equipmentOptions = [
    "Bodyweight",
    "Dumbbells",
    "Resistance Bands",
    "Gym Machines",
    "Kettlebell"
  ];
  final intensityOptions = ["Low", "Moderate", "High"];
  final bodyAreas = ["Chest", "Back", "Arms", "Legs", "Core", "Full Body"];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _loadProfileAndInit();
  }

  Future<void> _loadProfileAndInit() async {
    setState(() => loadingProfile = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('profiles').doc(uid).get();
        if (doc.exists) {
          profileData = doc.data();
          final g = (profileData?['gender'] ?? "").toString().toLowerCase();
          _isFemale = g == 'female';
        }
      }
    } catch (_) {
      profileData = null;
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  String _assetFor(String fileName) {
    return _isFemale ? "assets/fe_$fileName" : "assets/$fileName";
  }

  // 🔥 ADVANCED LOGIC: Dynamic Scaling based on Intensity
  WorkoutDay _generatePlan() {
    // 1. Define Multipliers
    double repMultiplier = 1.0;

    if (intensity == "Low") {
      repMultiplier = 0.8;
    } else if (intensity == "High") {
      repMultiplier = 1.4;
    }

    // 2. Define Exercise Pool
    final chest = [
      Exercise("Push-ups", 3, (10 * repMultiplier).toInt(), (15 * repMultiplier).toInt(), assetImage: _assetFor("pushup.png")),
      Exercise("Incline Push-ups", 3, (8 * repMultiplier).toInt(), (12 * repMultiplier).toInt(), assetImage: _assetFor("incline_pushup.png")),
    ];
    final legs = [
      Exercise("Lunges", 3, (10 * repMultiplier).toInt(), (16 * repMultiplier).toInt(), assetImage: _assetFor("lunges.png")),
      Exercise("Squats", 3, (12 * repMultiplier).toInt(), (20 * repMultiplier).toInt(), assetImage: _assetFor("squats.png")),
    ];
    final core = [
      Exercise("Plank", 3, 30, 60, isTime: true, assetImage: _assetFor("plank.png")),
      Exercise("Russian Twists", 3, (15 * repMultiplier).toInt(), (30 * repMultiplier).toInt(), assetImage: _assetFor("russian_twists.png")),
    ];
    final arms = [
      Exercise("Bicep Curls", 3, (10 * repMultiplier).toInt(), (15 * repMultiplier).toInt(), equipment: "Dumbbells", assetImage: _assetFor("bicep_curls.png")),
    ];

    // 3. Selection Logic
    List<Exercise> pool = [];
    if (targetAreas.contains("Full Body")) {
      pool = [...chest, ...legs, ...core, ...arms];
      pool.shuffle(); // Randomize full body
    } else {
      for (var area in targetAreas) {
        if (area == "Chest") pool.addAll(chest);
        if (area == "Legs") pool.addAll(legs);
        if (area == "Core") pool.addAll(core);
        if (area == "Arms") pool.addAll(arms);
      }
    }

    // 4. Time Calculation
    int exercisesCount = (durationMinutes / 5).floor().clamp(2, pool.isNotEmpty ? pool.length : 2);
    final selectedExercises = pool.take(exercisesCount).toList();

    // 5. Calorie Estimator Formula
    double met = intensity == "High" ? 8.0 : (intensity == "Moderate" ? 5.0 : 3.0);
    int estCalories = ((met * 3.5 * 70) / 200 * durationMinutes).toInt();

    return WorkoutDay(
      title: "Generated ${_dayName()}",
      durationMinutes: durationMinutes.toInt(),
      intensity: intensity,
      exercises: selectedExercises,
      caloriesBurned: estCalories,
    );
  }

  String _dayName() {
    return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][DateTime.now().weekday - 1];
  }

  void _generatePressed() {
    setState(() => generating = true);
    _animController.reset();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          generatedPlan = _generatePlan();
          generating = false;
        });
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    if (loadingProfile) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            // 1. Header
            _buildHeader(),

            // 2. Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Configuration Card
                  _buildConfigCard(),

                  const SizedBox(height: 25),

                  // Result Area
                  if (generating)
                    _buildLoadingState()
                  else if (generatedPlan != null)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildWorkoutPlanCard(generatedPlan!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade800, Colors.deepOrange.shade400],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Smart Trainer", style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)),
          SizedBox(height: 5),
          Text("Design Your Workout", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider("Duration", "${durationMinutes.toInt()} min", durationMinutes, 15, 90, (v) => setState(() => durationMinutes = v)),
          const SizedBox(height: 20),
          _buildDropdown("Intensity", intensity, intensityOptions, (v) => setState(() => intensity = v!)),
          const SizedBox(height: 20),
          _buildDropdown("Equipment", equipment, equipmentOptions, (v) => setState(() => equipment = v!)),
          const SizedBox(height: 20),
          _buildFilterChips("Target Muscle", bodyAreas),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: generating ? null : _generatePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                elevation: 4,
                shadowColor: Colors.deepOrange.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("GENERATE PLAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPlanCard(WorkoutDay day) {
    return Column(
      children: [
        // Summary Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatBadge(Icons.timer, "${day.durationMinutes} min", Colors.blue),
            _buildStatBadge(Icons.local_fire_department, "~${day.caloriesBurned} cal", Colors.red),
            _buildStatBadge(Icons.fitness_center, "${day.exercises.length} Exercises", Colors.orange),
          ],
        ),
        const SizedBox(height: 20),

        // Exercise List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: day.exercises.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ex = day.exercises[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  // Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey.shade100,
                      child: Image.asset(ex.assetImage ?? _assetFor("default.png"), fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.fitness_center, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildTag("${ex.sets} Sets", Colors.deepOrange.shade50, Colors.deepOrange),
                            const SizedBox(width: 8),
                            _buildTag(ex.isTime ? "${ex.repLow}s" : "${ex.repLow}-${ex.repHigh} Reps", Colors.blue.shade50, Colors.blue),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 30),

        // 🔥 CHANGED BUTTON COLOR TO APP COLOR (DeepOrange)
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: () => _startWorkout(day),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text("START WORKOUT SESSION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange, // Changed from black87
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.deepOrange.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(color: Colors.deepOrange),
        const SizedBox(height: 20),
        Text("AI is crafting your plan...", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }

  Widget _buildSlider(String label, String valueLabel, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            Text(valueLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          ],
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          divisions: (max - min) ~/ 5,
          activeColor: Colors.deepOrange,
          inactiveColor: Colors.deepOrange.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(String label, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            bool selected = targetAreas.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: selected,
              selectedColor: Colors.deepOrange.withOpacity(0.2),
              checkmarkColor: Colors.deepOrange,
              labelStyle: TextStyle(color: selected ? Colors.deepOrange.shade900 : Colors.black87),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    targetAreas.add(opt);
                  } else {
                    targetAreas.remove(opt);
                  }
                  if (opt == "Full Body" && val) targetAreas = ["Full Body"];
                  else if (opt != "Full Body") targetAreas.remove("Full Body");
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _startWorkout(WorkoutDay day) async {
    final bool? didComplete = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          exercises: day.exercises,
          totalDurationMinutes: day.durationMinutes,
        ),
      ),
    );
    if (didComplete == true) {
      setState(() => day.completed = true);
    }
  }
}

// --- DATA CLASSES ---

class WorkoutDay {
  final String title;
  final int durationMinutes;
  final String intensity;
  final int caloriesBurned;
  final List<Exercise> exercises;
  bool completed;

  WorkoutDay({
    required this.title,
    required this.durationMinutes,
    required this.intensity,
    required this.caloriesBurned,
    required this.exercises,
    this.completed = false,
  });
}

class Exercise {
  final String name;
  int sets;
  int repLow;
  int repHigh;
  String? equipment;
  bool isTime;
  String? assetImage;

  Exercise(this.name, this.sets, this.repLow, this.repHigh, {this.equipment, this.isTime = false, this.assetImage});

  String describe() {
    if (isTime) {
      return "$name — $repLow-$repHigh sec ($sets sets)";
    }
    return "$name — $sets sets × $repLow-$repHigh reps${equipment != null ? " ($equipment)" : ""}";
  }
}