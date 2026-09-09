// meal_provider.dart placeholder
import 'package:flutter/material.dart';
import '../models/meal_model.dart';

class MealProvider with ChangeNotifier {
  // ignore: prefer_final_fields
  List<MealModel> _meals = [];

  List<MealModel> get meals => _meals;

  void addMeal(MealModel meal) {
    _meals.add(meal);
    notifyListeners();
  }
}
