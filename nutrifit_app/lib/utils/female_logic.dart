// lib/utils/female_logic.dart
import 'package:flutter/material.dart';
import 'dart:math';

enum CyclePhase { Menstrual, Follicular, Ovulation, Luteal, Unknown }

class FemaleProfile {
  final String gender; // "Male" / "Female"
  final bool isPregnant;
  final DateTime? lastPeriodDate; // optional
  final int cycleLength; // default 28
  final int lutealLength; // default 14 (days from ovulation to next period)

  FemaleProfile({
    required this.gender,
    this.isPregnant = false,
    this.lastPeriodDate,
    this.cycleLength = 28,
    this.lutealLength = 14,
  });

  bool get isFemale => gender.toLowerCase() == 'female';
}

class FemaleLogic {
  /// returns cycle day (1..cycleLength) if lastPeriodDate provided, else null
  static int? cycleDayFromLastPeriod(DateTime? lastPeriod, int cycleLength) {
    if (lastPeriod == null) return null;
    final now = DateTime.now();
    final diff = now.difference(DateTime(lastPeriod.year, lastPeriod.month, lastPeriod.day)).inDays;
    final day = (diff % cycleLength) + 1;
    return day >= 1 ? day : 1;
  }

  /// returns CyclePhase (Menstrual/Follicular/Ovulation/Luteal)
  static CyclePhase cyclePhase(FemaleProfile profile) {
    final last = profile.lastPeriodDate;
    if (last == null) return CyclePhase.Unknown;
    final day = cycleDayFromLastPeriod(last, profile.cycleLength);
    if (day == null) return CyclePhase.Unknown;

    // approximate boundaries:
    // Menstrual: day 1-5
    // Follicular: day 6-(ovulation-1)
    // Ovulation: around day (cycleLength - lutealLength) ±1
    // Luteal: rest
    final ovulationDay = profile.cycleLength - profile.lutealLength;
    if (day >= 1 && day <= min(5, profile.cycleLength)) return CyclePhase.Menstrual;
    if (day >= ovulationDay - 1 && day <= ovulationDay + 1) return CyclePhase.Ovulation;
    if (day > 5 && day < ovulationDay - 1) return CyclePhase.Follicular;
    return CyclePhase.Luteal;
  }

  /// For pregnant users, return trimester (1..3) or null
  static int? pregnancyTrimester(bool isPregnant, {int pregnancyWeek = 0}) {
    if (!isPregnant) return null;
    if (pregnancyWeek <= 13) return 1;
    if (pregnancyWeek <= 27) return 2;
    return 3;
  }

  /// Returns simple food suggestions based on phase/pregnancy
  static List<String> foodSuggestions(FemaleProfile profile) {
    if (!profile.isFemale) return const [];

    if (profile.isPregnant) {
      return [
        "Include folate-rich foods (leafy greens, lentils).",
        "Add safe protein (cooked lean meat, legumes).",
        "Avoid raw/undercooked fish and unpasteurized cheese.",
        "Increase healthy fats (omega-3) and fiber."
      ];
    }

    final phase = cyclePhase(profile);
    switch (phase) {
      case CyclePhase.Menstrual:
        return ["Iron-rich foods (spinach, lentils)", "Magnesium-rich (nuts)", "Hydrate well"];
      case CyclePhase.Follicular:
        return ["Lean protein for strength gains", "Complex carbs for energy", "Vitamin C-rich fruits"];
      case CyclePhase.Ovulation:
        return ["Stay hydrated", "Anti-inflammatory foods", "Balanced meals to manage energy"];
      case CyclePhase.Luteal:
        return ["Complex carbs for cravings", "Magnesium & calcium rich foods", "Reduce salt"];
      case CyclePhase.Unknown:
        return ["Balanced plate: protein + veg + whole grains", "Track cycle info in your profile"];
    }
  }

  /// Returns workout adjustments / warnings
  static List<String> workoutAdjustments(FemaleProfile profile) {
    if (!profile.isFemale) return const [];

    if (profile.isPregnant) {
      final trimester = pregnancyTrimester(true, pregnancyWeek: 20) ?? 2; // default dummy
      if (trimester == 1) {
        return ["Moderate cardio, avoid high-impact", "Avoid Valsalva / heavy loads", "Consult provider if unsure"];
      } else if (trimester == 2) {
        return ["Good time for strength & mobility", "Avoid supine position for long periods", "Pelvic floor work recommended"];
      } else {
        return ["Focus on mobility & breathing", "Avoid heavy weights & high-intensity", "Prioritize comfort and balance"];
      }
    }

    final phase = cyclePhase(profile);
    switch (phase) {
      case CyclePhase.Menstrual:
        return ["Prefer low-impact (yoga, light walk)", "Add longer warmups", "Listen to your body"];
      case CyclePhase.Follicular:
        return ["Great time for strength/HIIT", "Push heavier if comfortable"];
      case CyclePhase.Ovulation:
        return ["High energy — but be careful with heavy lifts", "Focus on form to avoid injury"];
      case CyclePhase.Luteal:
        return ["Moderate workouts; manage cravings", "Include recovery days"];
      case CyclePhase.Unknown:
        return ["Balanced mix of cardio & strength", "Add rest days as needed"];
    }
  }
}
