// lib/utils/ai_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIRecognitionResult {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  AIRecognitionResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

/// Provides camera access, image picking, and sending to recognition endpoint.
/// For now the recognizeImage function uses a mock fallback when no real endpoint is configured.
class AIService {
  static final picker = ImagePicker();

  /// Requests camera permission using permission_handler
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Opens camera and returns the picked file path, or null if cancelled
  static Future<String?> pickImageFromCamera() async {
    final XFile? picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    return picked?.path;
  }

  /// Send image to your AI endpoint. If you don't have one, it returns a mocked result.
  /// Replace endpointUrl and request payload with your actual model/API contract.
  static Future<AIRecognitionResult> recognizeImage(String imagePath, {String? endpointUrl}) async {
    // If you have an endpoint, upload the file and parse the response.
    if (endpointUrl != null && endpointUrl.isNotEmpty) {
      final uri = Uri.parse(endpointUrl);
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Expecting {name, calories, protein, carbs, fat}
        return AIRecognitionResult(
          name: data['name'] ?? 'Unknown Food',
          calories: (data['calories'] ?? 0).toInt(),
          protein: (data['protein'] ?? 0).toDouble(),
          carbs: (data['carbs'] ?? 0).toDouble(),
          fat: (data['fat'] ?? 0).toDouble(),
        );
      } else {
        throw Exception('Recognition failed (${response.statusCode})');
      }
    }

    // Mock fallback: very simple heuristic based on filename (this is just a placeholder)
    final lower = imagePath.toLowerCase();
    if (lower.contains('salmon')) {
      return AIRecognitionResult(name: 'Salmon & Sweet Potato', calories: 540, protein: 42, carbs: 38, fat: 22);
    }
    if (lower.contains('wrap') || lower.contains('chicken')) {
      return AIRecognitionResult(name: 'Chicken Wrap', calories: 420, protein: 38, carbs: 30, fat: 18);
    }
    // Default mock:
    return AIRecognitionResult(name: 'Mixed Meal (estimated)', calories: 420, protein: 25, carbs: 45, fat: 15);
  }
}
