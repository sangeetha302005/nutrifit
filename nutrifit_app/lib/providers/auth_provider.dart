// auth_provider.dart placeholder
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? user;

  Future<bool> login(String email, String password) async {
    try {
      user = await _authService.login(email, password);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signup(String email, String password) async {
    try {
      user = await _authService.signup(email, password);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user = null;
    notifyListeners();
  }
}
