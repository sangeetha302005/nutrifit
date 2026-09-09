// lib/screens/profile/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Core fields
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  String? _gender;
  String? _activity;
  String? _diet;
  String? _goal;

  // Female fields
  bool _trackPeriods = false;
  bool _isPregnant = false;
  DateTime? _lastPeriodDate;
  int _pregnancyMonth = 1;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // -------------------- LOAD PROFILE --------------------
  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final snap = await _db.collection("profiles").doc(uid).get();
      if (!snap.exists) {
        setState(() => _loading = false);
        return;
      }

      final data = snap.data()!;

      _name.text = (data["name"] ?? "").toString();
      _age.text = (data["age"] ?? "").toString();
      _height.text = (data["height"] ?? "").toString();
      _weight.text = (data["weight"] ?? "").toString();

      _gender = data["gender"];
      _activity = data["activityLevel"];
      _diet = data["dietPreference"];
      _goal = data["healthGoal"];

      // Female Nested Map
      final female = data["female"] as Map<String, dynamic>?;

      if (female != null) {
        final flags = female["flags"] as Map<String, dynamic>? ?? {};

        _isPregnant = flags["isPregnant"] == true;
        _trackPeriods = flags["trackPeriods"] == true;

        if (_isPregnant) {
          _pregnancyMonth = (female["pregnancyMonth"] ?? 1);
        } else if (_trackPeriods) {
          final iso = female["lastPeriodDate"] as String?;
          if (iso != null) _lastPeriodDate = DateTime.tryParse(iso);
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------- DATE PICKER --------------------
  Future<void> _pickLastPeriodDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _lastPeriodDate = picked);
    }
  }

  // -------------------- SAVE PROFILE --------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == "Female") {
      if (_isPregnant && (_pregnancyMonth < 1 || _pregnancyMonth > 9)) {
        _snack("Pregnancy month must be 1-9");
        return;
      }

      if (_trackPeriods && _lastPeriodDate == null) {
        _snack("Please select last period date");
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final uid = _auth.currentUser!.uid;

      // Female data block (only if gender = Female)
      Map<String, dynamic> femaleData = {};

      if (_gender == "Female") {
        femaleData = {
          "flags": {
            "isPregnant": _isPregnant,
            "trackPeriods": !_isPregnant && _trackPeriods,
          },
          "pregnancyMonth": _isPregnant ? _pregnancyMonth : null,
          "lastPeriodDate":
          _trackPeriods ? _lastPeriodDate?.toIso8601String() : null,
        };
      } else {
        // If user changes to male/other, reset female flags safely
        femaleData = {
          "flags": {"isPregnant": false, "trackPeriods": false},
          "pregnancyMonth": null,
          "lastPeriodDate": null,
        };
      }

      final data = {
        "name": _name.text.trim(),
        "age": int.tryParse(_age.text.trim()) ?? 0,
        "height": double.tryParse(_height.text.trim()) ?? 0.0,
        "weight": double.tryParse(_weight.text.trim()) ?? 0.0,
        "gender": _gender,
        "activityLevel": _activity,
        "dietPreference": _diet,
        "healthGoal": _goal,
        "female": femaleData,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await _db.collection("profiles").doc(uid).set(data, SetOptions(merge: true));

      _snack("Profile saved successfully!");

      if (mounted) {
        Navigator.pushReplacementNamed(context, "/dashboard");
      }
    } catch (e) {
      _snack("Failed to save: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------- UI BUILD --------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final titleStyle =
    Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create / Edit Profile"),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("Personal", style: titleStyle),
              const SizedBox(height: 10),

              _field("Name", _name, Icons.person,
                      (v) => v!.isEmpty ? "Required" : null),

              const SizedBox(height: 12),
              _field("Age", _age, Icons.cake, (v) {
                if (int.tryParse(v ?? "") == null) return "Enter valid age";
                return null;
              }, keyboard: TextInputType.number),

              const SizedBox(height: 12),
              _dropdown(
                label: "Gender",
                value: _gender,
                icon: Icons.wc,
                items: const ["Male", "Female", "Other"],
                onChanged: (v) => setState(() => _gender = v),
              ),

              const SizedBox(height: 20),
              Text("Body Metrics", style: titleStyle),

              const SizedBox(height: 10),
              _field("Height (cm)", _height, Icons.height, (v) {
                if (double.tryParse(v ?? "") == null) return "Invalid height";
                return null;
              }, keyboard: TextInputType.number),

              const SizedBox(height: 12),
              _field("Weight (kg)", _weight, Icons.monitor_weight, (v) {
                if (double.tryParse(v ?? "") == null) return "Invalid weight";
                return null;
              }, keyboard: TextInputType.number),

              const SizedBox(height: 20),
              Text("Lifestyle", style: titleStyle),

              const SizedBox(height: 10),
              _dropdown(
                label: "Activity Level",
                value: _activity,
                icon: Icons.run_circle,
                items: const ["Sedentary", "Light", "Medium", "High"],
                onChanged: (v) => setState(() => _activity = v),
              ),

              const SizedBox(height: 12),
              _dropdown(
                label: "Diet Preference",
                value: _diet,
                icon: Icons.restaurant,
                items: const ["Balanced", "Vegetarian", "Vegan", "Keto", "Non-Veg"],
                onChanged: (v) => setState(() => _diet = v),
              ),

              const SizedBox(height: 12),
              _dropdown(
                label: "Health Goal",
                value: _goal,
                icon: Icons.flag,
                items: const ["Weight Loss", "Muscle Gain", "Maintenance", "Weight Gain"],
                onChanged: (v) => setState(() => _goal = v),
              ),

              const SizedBox(height: 25),

              // -------- FEMALE HEALTH --------
              if (_gender == "Female") ...[
                Text("Female Health", style: titleStyle),
                const SizedBox(height: 10),

                _switch(
                  "Currently Pregnant",
                  _isPregnant,
                      (v) => setState(() {
                    _isPregnant = v;
                    if (v) _trackPeriods = false;
                  }),
                ),
                _switch(
                  "Track Periods",
                  _trackPeriods,
                      (v) => setState(() {
                    _trackPeriods = v;
                    if (v) _isPregnant = false;
                  }),
                ),

                if (_isPregnant)
                  _pregnancyMonthPicker(),

                if (_trackPeriods)
                  _periodDatePicker(),
              ],

              const SizedBox(height: 30),
              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _save,
                child: const Text("Save & Continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- WIDGET HELPERS --------------------

  Widget _field(
      String label,
      TextEditingController controller,
      IconData icon,
      String? Function(String?) validator, {
        TextInputType keyboard = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField(
      value: value,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null ? "Required" : null,
    );
  }

  Widget _switch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _pregnancyMonthPicker() {
    return Row(
      children: [
        const Icon(Icons.pregnant_woman),
        const SizedBox(width: 12),
        const Text("Pregnancy Month"),
        const Spacer(),
        DropdownButton<int>(
          value: _pregnancyMonth,
          onChanged: (v) => setState(() => _pregnancyMonth = v ?? 1),
          items: List.generate(
            9,
                (i) => DropdownMenuItem(value: i + 1, child: Text("${i + 1}")),
          ),
        )
      ],
    );
  }

  Widget _periodDatePicker() {
    final text = _lastPeriodDate == null
        ? "Pick date"
        : "${_lastPeriodDate!.year}-${_lastPeriodDate!.month}-${_lastPeriodDate!.day}";

    return ListTile(
      title: const Text("Last Period Date"),
      subtitle: Text(text),
      trailing: OutlinedButton(
        onPressed: _pickLastPeriodDate,
        child: const Text("Select"),
      ),
    );
  }
}
