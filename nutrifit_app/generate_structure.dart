import 'dart:io';

void main() {
  // Base lib folder
  final baseDir = Directory('lib');

  // Folder structure
  final structure = {
    'constants': ['colors.dart', 'strings.dart', 'styles.dart'],
    'models': ['user_model.dart', 'meal_model.dart', 'workout_model.dart'],
    'providers': [
      'auth_provider.dart',
      'user_provider.dart',
      'meal_provider.dart',
      'workout_provider.dart',
    ],
    'services': [
      'auth_service.dart',
      'firestore_service.dart',
      'storage_service.dart',
    ],
    'screens': {
      'auth': [
        'login_screen.dart',
        'signup_screen.dart',
        'forgot_password_screen.dart',
      ],
      'profile': ['profile_screen.dart', 'edit_profile_screen.dart'],
      'meals': [
        'meal_list_screen.dart',
        'add_meal_screen.dart',
        'meal_detail_screen.dart',
      ],
      'dashboard': ['dashboard_screen.dart', 'charts_widget.dart'],
      'recipes': ['recipe_screen.dart', 'recipe_detail_screen.dart'],
      'workouts': ['workout_screen.dart', 'workout_detail_screen.dart'],
      'settings': ['settings_screen.dart', 'language_screen.dart'],
    },
    'widgets': [
      'custom_button.dart',
      'custom_textfield.dart',
      'meal_card.dart',
      'workout_card.dart',
    ],
    'utils': ['validators.dart', 'date_utils.dart', 'notification_helper.dart'],
  };

  createStructure(baseDir, structure);
}

void createStructure(Directory base, Map<String, dynamic> structure) {
  structure.forEach((key, value) {
    final dir = Directory('${base.path}/$key');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    if (value is List) {
      for (var fileName in value) {
        final file = File('${dir.path}/$fileName');
        if (!file.existsSync())
          // ignore: curly_braces_in_flow_control_structures
          file.writeAsStringSync('// $fileName placeholder\n');
      }
    } else if (value is Map<String, dynamic>) {
      createStructure(dir, value);
    }
  });
}
