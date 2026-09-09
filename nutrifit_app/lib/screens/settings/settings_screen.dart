// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback

// NOTE: Ensure this path is correct in your project
import '../auth/login_screen.dart';

// =========================================================================
// THEME NOTIFIER LOGIC
// =========================================================================

class ThemeNotifier {
  static ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static const Color _primaryColor = Colors.deepOrange;

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS-style light grey
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    colorScheme: ColorScheme.light(primary: _primaryColor, secondary: _primaryColor),
    useMaterial3: true,
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: const Color(0xFF000000), // Pure black
    cardColor: const Color(0xFF1C1C1E), // Dark grey for cards
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    colorScheme: ColorScheme.dark(primary: _primaryColor, secondary: _primaryColor),
    useMaterial3: true,
  );

  static void toggleTheme(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    HapticFeedback.mediumImpact();
  }
}

// =========================================================================
// MAIN SETTINGS SCREEN (ADVANCED)
// =========================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- State Variables ---
  String selectedLanguage = 'English';
  bool pushNotifications = true;
  bool biometricsEnabled = false;
  bool emailUpdates = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);

  // --- Actions ---

  Future<void> _selectLanguage() async {
    final language = await showDialog<String>(
      context: context,
      builder: (context) => LanguageDialog(selected: selectedLanguage),
    );
    if (language != null) setState(() => selectedLanguage = language);
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (time != null) setState(() => reminderTime = time);
  }

  Future<void> _logout() async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out of NutriFit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    // Determine current theme for conditional colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // 1. Advanced Slipping Header
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.deepOrange,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange.shade800, Colors.orangeAccent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Spacing for status bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Settings Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // --- SECTION: GENERAL ---
                  _buildSectionHeader("General"),
                  _buildSettingsGroup([
                    _buildCustomTile(
                      icon: Icons.language,
                      iconColor: Colors.blue,
                      title: "Language",
                      value: selectedLanguage,
                      onTap: _selectLanguage,
                    ),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeNotifier.themeMode,
                      builder: (context, mode, child) {
                        final isDarkMode = mode == ThemeMode.dark;
                        return _buildSwitchTile(
                          icon: Icons.dark_mode,
                          iconColor: Colors.purple,
                          title: "Dark Mode",
                          value: isDarkMode,
                          onChanged: (val) => ThemeNotifier.toggleTheme(val),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // --- SECTION: NOTIFICATIONS ---
                  _buildSectionHeader("Notifications"),
                  _buildSettingsGroup([
                    _buildSwitchTile(
                      icon: Icons.notifications_active,
                      iconColor: Colors.redAccent,
                      title: "Push Notifications",
                      value: pushNotifications,
                      onChanged: (val) => setState(() => pushNotifications = val),
                    ),
                    if (pushNotifications)
                      _buildCustomTile(
                        icon: Icons.access_time_filled,
                        iconColor: Colors.orange,
                        title: "Daily Reminder",
                        value: reminderTime.format(context),
                        onTap: _pickReminderTime,
                      ),
                    _buildSwitchTile(
                      icon: Icons.email,
                      iconColor: Colors.green,
                      title: "Email Tips & Updates",
                      value: emailUpdates,
                      onChanged: (val) => setState(() => emailUpdates = val),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // --- SECTION: SECURITY ---
                  _buildSectionHeader("Security"),
                  _buildSettingsGroup([
                    _buildSwitchTile(
                      icon: Icons.face,
                      iconColor: Colors.teal,
                      title: "Face ID / Biometrics",
                      value: biometricsEnabled,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() => biometricsEnabled = val);
                      },
                    ),
                    _buildCustomTile(
                      icon: Icons.lock_reset,
                      iconColor: Colors.grey,
                      title: "Change Password",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password reset email sent.")));
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // --- SECTION: SUPPORT & LEGAL ---
                  _buildSectionHeader("Support"),
                  _buildSettingsGroup([
                    _buildCustomTile(
                      icon: Icons.help,
                      iconColor: Colors.blueGrey,
                      title: "Help & Support",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                    ),
                    _buildCustomTile(
                      icon: Icons.privacy_tip,
                      iconColor: Colors.indigo,
                      title: "Privacy Policy",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    ),
                    _buildCustomTile(
                      icon: Icons.description,
                      iconColor: Colors.brown,
                      title: "Terms of Service",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen())),
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // --- LOGOUT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _logout,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Log Out",
                        style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "NutriFit AI v1.0.0",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Creates the "Island" container for grouped settings
  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          // Add dividers between items, but not after the last one
          return Column(
            children: [
              child,
              if (idx != children.length - 1)
                Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.2)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // A standard navigation tile (icon + text + arrow)
  Widget _buildCustomTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  // A switch tile (icon + text + toggle)
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: (val) {
          HapticFeedback.lightImpact(); // Add tactile feel
          onChanged(val);
        },
        activeColor: Colors.deepOrange,
      ),
    );
  }
}

// =========================================================================
// 🟢 SUPPORTING SCREENS (RESTORED CONTENT)
// =========================================================================

class LanguageDialog extends StatelessWidget {
  final String selected;
  const LanguageDialog({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final languages = ["English", "Spanish", "French", "German", "Hindi"];
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Select Language"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final lang = languages[index];
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: selected,
              activeColor: Colors.deepOrange,
              onChanged: (val) => Navigator.of(context).pop(val),
            );
          },
        ),
      ),
    );
  }
}

// --- Help & Support with Full FAQ ---
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const Color _primaryColor = Colors.deepOrange;

  static final Map<String, List<Map<String, String>>> supportTopics = {
    "Troubleshooting": [
      {
        "question": "Notifications Not Arriving",
        "answer": "1. Go to Phone Settings > Apps > NutriFit-AI > Notifications.\n2. Ensure 'Allow Notifications' is ON.\n3. Check 'Do Not Disturb' mode."
      },
      {
        "question": "App Crashing",
        "answer": "Please try clearing the app cache or reinstalling the app. If the issue persists, contact support."
      },
    ],
    "Account": [
      {
        "question": "Reset Password",
        "answer": "Log out, then tap 'Forgot Password' on the login screen to receive a reset link."
      },
      {
        "question": "Delete Account",
        "answer": "This can be done via Settings > Delete Account. Warning: This is permanent."
      },
    ]
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ...supportTopics.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                const Divider(),
                ...entry.value.map((qa) => ExpansionTile(
                  title: Text(qa['question']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  children: [Padding(padding: const EdgeInsets.all(16.0), child: Text(qa['answer']!))],
                )),
                const SizedBox(height: 20),
              ],
            );
          }),
          const SizedBox(height: 20),
          const Text("Contact Us", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email, color: _primaryColor),
            title: const Text("Email Support"),
            subtitle: const Text("support@nutrifit.ai"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// --- Privacy Policy with Content ---
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("1. Data Collection", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("We collect personal data such as name, age, height, and weight to provide personalized fitness plans."),
            SizedBox(height: 20),
            Text("2. Usage of Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Your data is used solely for app functionality. We do not sell your data to third parties."),
            SizedBox(height: 20),
            Text("3. Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("We use industry-standard encryption to protect your data stored in the cloud."),
          ],
        ),
      ),
    );
  }
}

// --- Terms with Content ---
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Conditions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("1. Acceptance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("By using this app, you agree to these terms. If you do not agree, please do not use the app."),
            SizedBox(height: 20),
            Text("2. Health Disclaimer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("This app provides information, not medical advice. Consult a doctor before starting any new diet or exercise program."),
            SizedBox(height: 20),
            Text("3. User Conduct", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("You agree to use the app responsibly and not for any illegal purposes."),
          ],
        ),
      ),
    );
  }
}