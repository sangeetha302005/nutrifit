// lib/widgets/profile_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: flutter pub add fl_chart
import 'package:percent_indicator/percent_indicator.dart'; // REQUIRED: flutter pub add percent_indicator
import 'package:cached_network_image/cached_network_image.dart'; // REQUIRED: flutter pub add cached_network_image

// --- IMPORTS (Adjust these paths to match your project) ---
import '../providers/user_provider.dart'; // Your provider file
import '../auth/login_screen.dart'; // Your Login Screen
import '../screens/auth/login_screen.dart';
import '../screens/settings/settings_screen.dart'; // Your Settings Screen

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with TickerProviderStateMixin {
  // --- KEYS & CONTROLLERS ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();

  // --- STATE VARIABLES ---
  String? _gender;
  String? _activityLevel;
  String? _dietPreference;
  String? _healthGoal;

  File? _newAvatarFile;
  String? _avatarUrl;

  bool _isSaving = false;
  bool _isInitialLoading = false;
  bool _isEditing = false; // Controls View vs Edit Mode
  bool _profileExists = false;
  int _currentStep = 0;

  final _picker = ImagePicker();
  Map<String, dynamic>? _profileData;

  // --- ANIMATIONS ---
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // --- COLORS ---
  static const Color _primary = Colors.deepOrange;
  static const Color _bg = Color(0xFFF5F7FA);

  Color? get _cardColor => null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  // ====================================================
  // 🔥 ACTIONS & LOGIC (FIXED)
  // ====================================================

  // 1. Navigation to Settings
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  // 2. Logout Logic
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Clear stack and go to Login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  // 3. Load Profile Data
  Future<void> _loadProfile() async {
    // Set defaults immediately so UI never blocks
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
        _profileExists = true;
        _isEditing = false;
        if (_nameController.text.isEmpty) _nameController.text = "NutriFit User";
        if (_ageController.text.isEmpty) _ageController.text = "25";
        if (_heightController.text.isEmpty) _heightController.text = "170";
        if (_weightController.text.isEmpty) _weightController.text = "65";
        _gender ??= "Female";
        _activityLevel ??= "Medium";
        _healthGoal ??= "Maintenance";
        _dietPreference ??= "Balanced";
      });
      _animController.forward();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 1));

      if (doc.exists && doc.data() != null) {
        _profileData = doc.data();
        _populateControllers(_profileData!);
        _profileExists = true;
        _isEditing = false;

        if (mounted) {
          final g = _profileData?['gender'];
          if (g != null) {
            Provider.of<UserProvider>(context, listen: false).setGender(_stringToGender(g));
          }
        }
      } else {
        _profileExists = true;
        _isEditing = false;
        _nameController.text = "NutriFit User";
        _ageController.text = "25";
        _heightController.text = "170";
        _weightController.text = "65";
        _gender = "Female";
        _activityLevel = "Medium";
        _healthGoal = "Maintenance";
        _dietPreference = "Balanced";
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      _profileExists = true;
      _isEditing = false;
      if (_nameController.text.isEmpty) _nameController.text = "NutriFit User";
      if (_ageController.text.isEmpty) _ageController.text = "25";
      if (_heightController.text.isEmpty) _heightController.text = "170";
      if (_weightController.text.isEmpty) _weightController.text = "65";
      _gender ??= "Female";
      _activityLevel ??= "Medium";
      _healthGoal ??= "Maintenance";
      _dietPreference ??= "Balanced";
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        _animController.forward();
      }
    }
  }

  void _populateControllers(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? 'NutriFit User';
    _ageController.text = (data['age'] ?? '25').toString();
    _heightController.text = (data['height'] ?? '170').toString();
    _weightController.text = (data['weight'] ?? '65').toString();
    _allergiesController.text = data['allergies'] ?? '';
    _gender = data['gender'] ?? 'Female';
    _activityLevel = data['activityLevel'] ?? 'Medium';
    _dietPreference = data['dietPreference'] ?? 'Balanced';
    _healthGoal = data['healthGoal'] ?? 'Maintenance';
    _avatarUrl = data['avatarUrl'];
  }

  // 4. Save Profile
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your name.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? newUrl = _avatarUrl;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        if (_newAvatarFile != null) {
          try {
            final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
            await ref.putFile(_newAvatarFile!);
            newUrl = await ref.getDownloadURL();
          } catch (e) {
            debugPrint("Avatar note: $e");
          }
        }

        final data = {
          'name': name,
          'age': int.tryParse(_ageController.text) ?? 25,
          'height': double.tryParse(_heightController.text) ?? 170,
          'weight': double.tryParse(_weightController.text) ?? 65,
          'gender': _gender ?? "Female",
          'activityLevel': _activityLevel ?? "Medium",
          'dietPreference': _dietPreference ?? "Balanced",
          'healthGoal': _healthGoal ?? "Maintenance",
          'allergies': _allergiesController.text.trim(),
          'avatarUrl': newUrl,
        };

        await FirebaseFirestore.instance.collection('profiles').doc(uid).set(data, SetOptions(merge: true));
      }

      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).updateProfile(
          name: name,
          age: int.tryParse(_ageController.text) ?? 25,
          height: double.tryParse(_heightController.text) ?? 170,
          weight: double.tryParse(_weightController.text) ?? 65,
          healthGoal: _healthGoal ?? "Maintenance",
          activityLevel: _activityLevel ?? "Medium",
          dietPreference: _dietPreference ?? "Balanced",
        );
        Provider.of<UserProvider>(context, listen: false).setGender(_stringToGender(_gender));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved Successfully!")));
        setState(() {
          _isEditing = false;
          _profileExists = true;
          _newAvatarFile = null;
          _currentStep = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEditing = false;
          _profileExists = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved!")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Gender _stringToGender(String? s) {
    if (s == "Female") return Gender.female;
    if (s == "Male") return Gender.male;
    return Gender.preferNotToSay;
  }

  Future<void> _pickAvatar() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) setState(() => _newAvatarFile = File(xFile.path));
  }

  // --- SCIENTIFIC CALCULATIONS ---
  double _calcBMI(double w, double h) => h <= 0 ? 0 : w / ((h / 100) * (h / 100));

  int _calcBMR(double w, double h, int age, String? gender) {
    if (w <= 0 || h <= 0 || age <= 0) return 0;
    double s = (gender == "Female") ? -161 : 5;
    return (10 * w + 6.25 * h - 5 * age + s).toInt();
  }

  int _calcTDEE(int bmr, String? act) {
    if (bmr == 0) return 0;
    double m = 1.2;
    if (act != null) {
      if (act.contains("Light")) m = 1.375;
      if (act.contains("Medium")) m = 1.55;
      if (act.contains("High")) m = 1.725;
    }
    return (bmr * m).toInt();
  }

  Map<String, int> _calcMacros(int tdee, String? goal) {
    if (tdee == 0) return {"target": 0, "protein": 0, "carbs": 0, "fat": 0};
    int target = tdee;
    if (goal == "Weight Loss") target = tdee - 500;
    if (goal == "Muscle Gain") target = tdee + 300;
    if (target < 1200) target = 1200; // Safety floor

    return {
      "target": target,
      "protein": (target * 0.35 / 4).toInt(),
      "carbs": (target * 0.40 / 4).toInt(),
      "fat": (target * 0.25 / 9).toInt(),
    };
  }

  // ====================================================
  // 🖥️ UI BUILDER
  // ====================================================

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    // TOGGLE: Edit vs View
    if (_isEditing || !_profileExists) {
      return _buildEditMode();
    } else {
      return _buildViewMode();
    }
  }

  // ----------------------------------------------------
  // 👀 VIEW MODE (Pro Dashboard)
  // ----------------------------------------------------
  Widget _buildViewMode() {
    // Data Extraction
    final double weight = double.tryParse(_weightController.text) ?? 0;
    final double height = double.tryParse(_heightController.text) ?? 0;
    final int age = int.tryParse(_ageController.text) ?? 0;

    // Calculate
    final double bmi = _calcBMI(weight, height);
    final int bmr = _calcBMR(weight, height, age, _gender);
    final int tdee = _calcTDEE(bmr, _activityLevel);
    final Map<String, int> macros = _calcMacros(tdee, _healthGoal);

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Sliver Header
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            backgroundColor: _primary,
            stretch: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => setState(() => _isEditing = true), // TRIGGER EDIT MODE
              )
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.deepOrange.shade800, Colors.orangeAccent],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                          child: _avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_nameController.text.isEmpty ? "User" : _nameController.text,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text("${_gender ?? 'User'} • $age yrs", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Content Body
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    _buildStatsRow(weight, height, bmi),
                    const SizedBox(height: 24),

                    // Nutrition Chart
                    const Text("Daily Nutrition Plan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildMacroCard(macros),
                    const SizedBox(height: 24),

                    // Metabolic Grid
                    const Text("Metabolic Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildScienceCard("BMR", "$bmr", "Base Burn", Colors.orange, "Calories burned at rest.")),
                        const SizedBox(width: 12),
                        Expanded(child: _buildScienceCard("TDEE", "$tdee", "Daily Burn", Colors.red, "Total daily energy expenditure.")),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildBodyStatsCard(weight, height, age, _gender),
                    const SizedBox(height: 24),

                    const Text("Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        children: [
                          _buildActionTile(Icons.edit, "Edit Profile", () => setState(() => _isEditing = true)),
                          const Divider(height: 1, indent: 50),
                          _buildActionTile(Icons.settings, "App Settings", _navigateToSettings), // FIX: Settings Link
                          const Divider(height: 1, indent: 50),
                          _buildActionTile(Icons.logout, "Log Out", _logout, isDestructive: true), // FIX: Logout Link
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ✏️ EDIT MODE (Stepper Form)
  // ----------------------------------------------------
  Widget _buildEditMode() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: _profileExists
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isEditing = false))
            : null,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          bool valid = false;
          if (_currentStep == 0) valid = _step1Key.currentState!.validate();
          if (_currentStep == 1) valid = _step2Key.currentState!.validate();
          if (_currentStep == 2) valid = _step3Key.currentState!.validate();

          if (valid) {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _saveProfile();
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (ctx, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.all(16)),
                    child: Text(_currentStep == 2 ? "SAVE" : "NEXT"),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(onPressed: details.onStepCancel, child: const Text("BACK")),
                ]
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text("Basic"),
            isActive: _currentStep >= 0,
            content: Form(
              key: _step1Key,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _newAvatarFile != null ? FileImage(_newAvatarFile!) : (_avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null) as ImageProvider?,
                      child: (_newAvatarFile == null && _avatarUrl == null) ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTxtField("Full Name", _nameController),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _buildTxtField("Age", _ageController, isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDropdown("Gender", _gender, ["Male", "Female", "Other"], (v) => setState(() => _gender = v!))),
                  ]),
                ],
              ),
            ),
          ),
          Step(
            title: const Text("Body"),
            isActive: _currentStep >= 1,
            content: Form(
              key: _step2Key,
              child: Column(
                children: [
                  _buildTxtField("Height (cm)", _heightController, isNum: true),
                  const SizedBox(height: 10),
                  _buildTxtField("Weight (kg)", _weightController, isNum: true),
                ],
              ),
            ),
          ),
          Step(
            title: const Text("Goals"),
            isActive: _currentStep >= 2,
            content: Form(
              key: _step3Key,
              child: Column(
                children: [
                  _buildDropdown("Activity", _activityLevel, ["Sedentary", "Light", "Medium", "High"], (v) => setState(() => _activityLevel = v!)),
                  const SizedBox(height: 10),
                  _buildDropdown("Goal", _healthGoal, ["Weight Loss", "Maintenance", "Muscle Gain"], (v) => setState(() => _healthGoal = v!)),
                  const SizedBox(height: 10),
                  _buildDropdown("Diet Type", _dietPreference, ["Balanced", "Vegetarian", "Vegan", "Keto"], (v) => setState(() => _dietPreference = v!)),
                  const SizedBox(height: 10),
                  _buildTxtField("Allergies (Optional)", _allergiesController, required: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildStatsRow(double w, double h, double bmi) {
    String bmiCat = "Normal";
    Color bmiColor = Colors.green;
    if(bmi < 18.5) { bmiCat = "Low"; bmiColor = Colors.blue; }
    else if(bmi >= 25) { bmiCat = "High"; bmiColor = Colors.orange; }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCol("Weight", "$w kg"),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _statCol("Height", "$h cm"),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          Column(
            children: [
              CircularPercentIndicator(
                radius: 25, lineWidth: 5, percent: (bmi/40).clamp(0.0, 1.0),
                center: Text(bmi.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                progressColor: bmiColor, backgroundColor: Colors.grey.shade100,
              ),
              const Text("BMI", style: TextStyle(fontSize: 12, color: Colors.grey))
            ],
          )
        ],
      ),
    );
  }

  Widget _statCol(String label, String val, {bool highlight = false}) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: highlight ? _primary : Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMacroCard(Map<String, int> macros) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          SizedBox(
            height: 90, width: 90,
            child: PieChart(PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 25,
                sections: [
                  PieChartSectionData(value: 35, color: Colors.blueAccent, radius: 12, showTitle: false),
                  PieChartSectionData(value: 40, color: Colors.green, radius: 12, showTitle: false),
                  PieChartSectionData(value: 25, color: Colors.orangeAccent, radius: 12, showTitle: false),
                ]
            )),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Target: ${macros['target']} kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                _macroRow("Protein", "${macros['protein']}g", Colors.blueAccent),
                _macroRow("Carbs", "${macros['carbs']}g", Colors.green),
                _macroRow("Fats", "${macros['fat']}g", Colors.orangeAccent),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _macroRow(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildScienceCard(String title, String val, String sub, Color color, String info) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(context: context, builder: (c) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 10),
            Text(info, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
          ]),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Icon(Icons.info_outline, size: 16, color: color),
            ]),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(sub, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyStatsCard(double w, double h, int age, String? gender) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCol("Weight", "$w kg"),
          _statCol("Height", "$h cm"),
          _statCol("Age", "$age yrs"),
          _statCol("Gender", gender ?? "N/A"),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDestructive ? Colors.red.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade800, size: 20),
      ),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildTxtField(String label, TextEditingController ctrl, {bool isNum = false, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => required && (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) onChange) {
    return DropdownButtonFormField<String>(
      value: val,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChange,
      validator: (v) => v == null ? "Required" : null,
    );
  }
}