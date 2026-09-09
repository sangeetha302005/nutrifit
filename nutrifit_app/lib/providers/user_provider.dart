// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../models/user_model.dart';

enum Gender { male, female, preferNotToSay }

class UserProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  // --- PERSONALIZATION & HEALTH STATE ---
  Gender _gender = Gender.female;
  bool _isPregnant = false;
  bool _isOnPeriod = false;

  String _name = "NutriFit User";
  int _age = 25;
  double _height = 170;
  double _weight = 65;
  String _healthGoal = "Maintenance";
  String _activityLevel = "Medium";
  String _dietPreference = "Balanced";

  // Calculated Targets
  int _targetCalories = 2100;
  int _targetProtein = 140;
  int _targetCarbs = 230;
  int _targetFat = 65;

  // Logged Intake
  double _eatenCalories = 0;
  double _eatenProtein = 0;
  double _eatenCarbs = 0;
  double _eatenFat = 0;

  // Getters
  Gender get gender => _gender;
  bool get isPregnant => _isPregnant;
  bool get isOnPeriod => _isOnPeriod;

  String get name => _name;
  int get age => _age;
  double get height => _height;
  double get weight => _weight;
  String get healthGoal => _healthGoal;
  String get activityLevel => _activityLevel;
  String get dietPreference => _dietPreference;

  int get targetCalories => _targetCalories;
  int get targetProtein => _targetProtein;
  int get targetCarbs => _targetCarbs;
  int get targetFat => _targetFat;

  double get eatenCalories => _eatenCalories;
  double get eatenProtein => _eatenProtein;
  double get eatenCarbs => _eatenCarbs;
  double get eatenFat => _eatenFat;

  void setGender(Gender newGender) {
    if (newGender == _gender) return;
    _gender = newGender;
    if (_gender != Gender.female) {
      _isPregnant = false;
      _isOnPeriod = false;
    }
    _recalculateTargets();
    notifyListeners();
  }

  void setPregnancyStatus(bool status) {
    if (status == _isPregnant) return;
    _isPregnant = status;
    if (_isPregnant) _isOnPeriod = false;
    _recalculateTargets();
    notifyListeners();
  }

  void setOnPeriodStatus(bool status) {
    if (status == _isOnPeriod) return;
    _isOnPeriod = status;
    if (_isOnPeriod) _isPregnant = false;
    _recalculateTargets();
    notifyListeners();
  }

  void updateProfile({
    required String name,
    required int age,
    required double height,
    required double weight,
    required String healthGoal,
    required String activityLevel,
    required String dietPreference,
  }) {
    _name = name.isNotEmpty ? name : _name;
    _age = age > 0 ? age : _age;
    _height = height > 0 ? height : _height;
    _weight = weight > 0 ? weight : _weight;
    _healthGoal = healthGoal;
    _activityLevel = activityLevel;
    _dietPreference = dietPreference;

    _recalculateTargets();
    notifyListeners();
  }

  void _recalculateTargets() {
    double bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) + (_gender == Gender.female ? -161 : 5);
    double factor = 1.375;
    if (_activityLevel.contains("Sedentary")) factor = 1.2;
    if (_activityLevel.contains("Medium")) factor = 1.55;
    if (_activityLevel.contains("High")) factor = 1.725;

    double tdee = bmr * factor;
    double target = tdee;
    if (_healthGoal == "Weight Loss") target = tdee - 500;
    if (_healthGoal == "Muscle Gain") target = tdee + 350;
    if (target < 1200) target = 1200;

    _targetCalories = target.toInt();
    _targetProtein = (_targetCalories * 0.30 / 4).toInt();
    _targetCarbs = (_targetCalories * 0.45 / 4).toInt();
    _targetFat = (_targetCalories * 0.25 / 9).toInt();
  }

  void setEatenNutrients(double cal, double prot, double carb, double fat) {
    _eatenCalories = cal;
    _eatenProtein = prot;
    _eatenCarbs = carb;
    _eatenFat = fat;
    notifyListeners();
  }

  void addEatenNutrients(double cal, double prot, double carb, double fat) {
    _eatenCalories += cal;
    _eatenProtein += prot;
    _eatenCarbs += carb;
    _eatenFat += fat;
    notifyListeners();
  }
}