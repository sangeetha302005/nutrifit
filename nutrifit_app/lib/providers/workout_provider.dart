// workout_provider.dart placeholder
import 'package:flutter/material.dart';
import '../models/workout_model.dart';

class WorkoutProvider with ChangeNotifier {
  // ignore: prefer_final_fields
  List<WorkoutModel> _workouts = [];

  List<WorkoutModel> get workouts => _workouts;

  void addWorkout(WorkoutModel workout) {
    _workouts.add(workout);
    notifyListeners();
  }
}
