import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  String gender = "Male";
  bool isPregnant = false;

  DateTime? lastPeriodDate;
  int? pregnancyMonth;

  Future<void> saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("users").doc(uid).set({
      "age": ageController.text,
      "height": heightController.text,
      "weight": weightController.text,
      "gender": gender,
      "isPregnant": gender == "Female" ? isPregnant : false,
      "lastPeriodDate": (gender == "Female" && !isPregnant && lastPeriodDate != null)
          ? lastPeriodDate!.toIso8601String()
          : null,
      "pregnancyMonth": (gender == "Female" && isPregnant) ? pregnancyMonth : null,
    }, SetOptions(merge: true));

    // After saving profile → Move to Dashboard
    Navigator.pushReplacementNamed(context, "/dashboard");
  }

  Future<void> pickLastPeriodDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => lastPeriodDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Basic Info", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Age"),
            ),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Height (cm)"),
            ),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Weight (kg)"),
            ),

            const SizedBox(height: 20),
            Text("Gender", style: Theme.of(context).textTheme.titleLarge),
            Row(
              children: [
                Radio(
                  value: "Male",
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value.toString()),
                ),
                const Text("Male"),
                Radio(
                  value: "Female",
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value.toString()),
                ),
                const Text("Female"),
              ],
            ),

            if (gender == "Female") ...[
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Are you pregnant?"),
                value: isPregnant,
                onChanged: (v) => setState(() => isPregnant = v),
              ),

              if (isPregnant) ...[
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Pregnancy Month"),
                  items: List.generate(9, (i) => i + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text("$m Month")))
                      .toList(),
                  onChanged: (v) => setState(() => pregnancyMonth = v),
                )
              ] else ...[
                TextButton(
                  onPressed: pickLastPeriodDate,
                  child: Text(
                    lastPeriodDate == null
                        ? "Select Last Period Date"
                        : "Last Period: ${lastPeriodDate!.toLocal()}".split(' ')[0],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: saveProfile,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: const Text("Save Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
