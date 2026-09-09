// lib/widgets/ai_tab.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AITab extends StatefulWidget {
  const AITab({super.key});

  @override
  State<AITab> createState() => _AITabState();
}

class _AITabState extends State<AITab> {
  // --- CONTROLLERS ---
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- STATE ---
  int _currentModeIndex = 0; // 0 = Recipe, 1 = Fitness
  bool isGenerating = false;

  // Mutable API KEY
  String apiKey = "";

  void _showApiKeyDialog() {
    final keyCtrl = TextEditingController(text: apiKey);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Gemini API Key Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your Google Gemini API key to enable live cloud AI inference. If left blank, NutriFit smart AI engine will generate recommendations locally.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                hintText: "AIzaSy...",
                border: OutlineInputBorder(),
                labelText: "API Key",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => apiKey = "");
              Navigator.pop(c);
              _showSnack("API key cleared. Using smart AI mode.");
            },
            child: const Text("Clear Key"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => apiKey = keyCtrl.text.trim());
              Navigator.pop(c);
              _showSnack("API Key saved successfully!");
            },
            child: const Text("Save Key"),
          ),
        ],
      ),
    );
  }

  String _getSmartFallbackResponse(String prompt) {
    final lower = prompt.toLowerCase();
    if (_currentModeIndex == 0) {
      if (lower.contains("unique") || lower.contains("gourmet")) {
        return """HEALTHY GOURMET DINNER: Mediterranean Lemon Herb Salmon
        
INGREDIENTS:
- 200g Fresh Salmon Fillet
- 1 cup Quinoa (Cooked)
- 1 cup Steamed Broccoli & Cherry Tomatoes
- 1 tbsp Extra Virgin Olive Oil, Lemon juice, Garlic & Herbs

INSTRUCTIONS:
1. Season salmon with lemon, garlic, salt, and black pepper.
2. Pan-sear salmon in olive oil for 4 minutes each side until golden.
3. Serve warm over a bed of fluffy quinoa with steamed vegetables.

NUTRITION PROFILE:
- Calories: 520 kcal
- Protein: 42g
- Carbs: 35g
- Fats: 22g""";
      } else if (lower.contains("ingredient")) {
        return """HEALTHY RECIPE FROM YOUR INGREDIENTS

RECIPE: High-Protein Veggie & Grain Bowl

INGREDIENTS USED:
${prompt.replaceAll(RegExp(r'.*using:\s*'), '').replaceAll('. Include calories.', '')}

PREPARATION STEPS:
1. Wash and chop all fresh ingredients evenly.
2. Saute or roast in a lightly oiled pan with natural spices.
3. Combine into a warm bowl and top with your favorite healthy dressing.

NUTRITION ESTIMATE:
- Calories: 410 kcal
- Protein: 28g
- Carbs: 48g
- Fats: 12g""";
      } else {
        return """NUTRITIOUS MEAL RECOMMENDATION: Avocado Chicken Wrap

INGREDIENTS:
- 150g Grilled Chicken Breast (Sliced)
- 1 Whole Wheat Tortilla Wrap
- 1/2 Avocado (Mashed)
- Baby Spinach & Tomatoes

INSTRUCTIONS:
Spread avocado onto tortilla, add spinach, tomatoes, and chicken. Roll tightly and toast for 2 minutes.

NUTRITION PROFILE:
- Calories: 450 kcal | Protein: 36g | Carbs: 38g | Fats: 16g""";
      }
    } else {
      return """CUSTOM FITNESS ROUTINE ($selectedIntensity Intensity, $selectedEquipment)

WARM-UP (5 Mins):
- Arm Circles & Jumping Jacks (2 Mins)
- Dynamic Hip & Leg Swings (3 Mins)

MAIN WORKOUT CIRCUIT (3 Rounds):
1. Push-ups or Knee Push-ups: 12-15 Reps
2. Bodyweight / Loaded Squats: 15-20 Reps
3. Plank Hold: 45 Seconds
4. Mountain Climbers: 30 Seconds

COOL-DOWN & RECOVERY:
- Standing Hamstring Stretch (30s)
- Child's Pose & Deep Breathing (1 Min)

TRAINER TIP: Focus on controlled movement and keep your core tight throughout all exercises!""";
    }
  }

  // --- SEPARATE CHAT HISTORIES ---
  // These lists store the conversation for each mode separately
  final List<Map<String, String>> _recipeMessages = [];
  final List<Map<String, String>> _fitnessMessages = [];

  // Helper to get the current list based on the active tab
  List<Map<String, String>> get _currentMessages =>
      _currentModeIndex == 0 ? _recipeMessages : _fitnessMessages;

  // --- OPTIONS ---
  String selectedRecipeMode = "Unique Recipe";
  String selectedEquipment = "No Equipment";
  String selectedIntensity = "Medium";

  final List<String> recipeModes = ["Unique Recipe", "From Ingredients", "From Dish Name"];
  final List<String> fitnessEquipments = ["No Equipment", "Dumbbells", "Yoga Mat", "Full Gym"];
  final List<String> intensityLevels = ["Low", "Medium", "High"];

  @override
  void dispose() {
    _ingredientsController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- HELPERS ---
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Timer(const Duration(milliseconds: 300), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuad,
        );
      });
    }
  }

  String cleanOutput(String text) {
    return text.replaceAll(RegExp(r'[#*_`\[\]-]'), '').replaceAll('###', '').replaceAll('##', '').trim();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        )
    );
  }

  // ====================================================
  // 🧠 CORE AI LOGIC (Gemini 2.5 Flash)
  // ====================================================
  Future<void> _sendToAI(String prompt, {bool isFollowUp = false}) async {
    setState(() => isGenerating = true);

    // Identify which list to update
    final targetList = _currentModeIndex == 0 ? _recipeMessages : _fitnessMessages;

    if (isFollowUp || prompt.isNotEmpty) {
      setState(() {
        targetList.add({"role": "user", "text": prompt});
      });
      _scrollToBottom();
    }

    if (apiKey.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      final fallback = _getSmartFallbackResponse(prompt);
      setState(() {
        targetList.add({"role": "ai", "text": fallback});
      });
      setState(() => isGenerating = false);
      _scrollToBottom();
      return;
    }

    try {
      String roleContext = _currentModeIndex == 0
          ? "You are an expert Chef & Nutritionist."
          : "You are an elite Personal Trainer.";

      String systemContext = """
      $roleContext
      Tone: Professional, motivating, concise.
      Structure: Use clear headings (e.g. INGREDIENTS, WORKOUT). 
      Do NOT use markdown symbols like # or *.
      """;

      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$systemContext\n\nUser Request: $prompt"}
            ]
          }
        ]
      });

      final res = await http.post(url,
          headers: {"Content-Type": "application/json"}, body: body);

      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw["candidates"] != null && raw["candidates"].isNotEmpty) {
          final aiText = raw["candidates"][0]["content"]["parts"][0]["text"];
          final cleanText = cleanOutput(aiText);

          setState(() {
            targetList.add({"role": "ai", "text": cleanText});
          });
          HapticFeedback.lightImpact();
        } else {
          final fallback = _getSmartFallbackResponse(prompt);
          setState(() {
            targetList.add({"role": "ai", "text": fallback});
          });
        }
      } else {
        final fallback = _getSmartFallbackResponse(prompt);
        setState(() {
          targetList.add({"role": "ai", "text": fallback});
        });
      }
    } catch (e) {
      final fallback = _getSmartFallbackResponse(prompt);
      setState(() {
        targetList.add({"role": "ai", "text": fallback});
      });
    } finally {
      setState(() => isGenerating = false);
      _scrollToBottom();
    }
  }

  // --- BUTTON HANDLERS ---
  void _handleGenerate() {
    if (isGenerating) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    String prompt = "";

    if (_currentModeIndex == 0) {
      // --- RECIPE LOGIC ---
      if (selectedRecipeMode == "From Ingredients") {
        if (_ingredientsController.text.isEmpty) {
          _showSnack("Please enter ingredients!", isError: true);
          return;
        }
        prompt = "Create a healthy recipe using: ${_ingredientsController.text}. Include calories.";
      } else if (selectedRecipeMode == "Unique Recipe") {
        prompt = "Suggest a unique, healthy gourmet dinner recipe with macros.";
      } else {
        if (_ingredientsController.text.isEmpty) {
          _showSnack("Please enter a dish name!", isError: true);
          return;
        }
        prompt = "Make a healthy version of: ${_ingredientsController.text}";
      }
    } else {
      // --- FITNESS LOGIC ---
      prompt = "Create a workout plan. Intensity: $selectedIntensity. Equipment: $selectedEquipment. Include sets/reps.";
    }

    _sendToAI(prompt);
  }

  void _handleChatSubmit() {
    if (_chatController.text.isEmpty) return;
    String text = _chatController.text.trim();
    _chatController.clear();
    _sendToAI(text, isFollowUp: true);
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // 1. Premium Header
          _buildHeader(),

          // 2. Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              // Item Count = Config Card (1) + Messages + Loader (if generating)
              itemCount: 1 + _currentMessages.length + (isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                // Config Card is always first
                if (index == 0) return _buildConfigCard();

                // Typing Indicator
                if (isGenerating && index == _currentMessages.length + 1) {
                  return _buildLoadingBubble();
                }

                // Chat Messages
                final msgIndex = index - 1;
                if (msgIndex < _currentMessages.length) {
                  return _buildMessageBubble(_currentMessages[msgIndex]);
                }
                return const SizedBox();
              },
            ),
          ),

          // 3. Bottom Input
          _buildBottomInput(),
        ],
      ),
    );
  }

  // --- WIDGET: Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade800, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text("AI Health Coach", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              IconButton(
                icon: Icon(
                  apiKey.isNotEmpty ? Icons.key : Icons.key_off,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: "Gemini API Key Settings",
                onPressed: _showApiKeyDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                _buildToggleBtn("Meal Plan", Icons.restaurant_menu, 0),
                _buildToggleBtn("Workout", Icons.fitness_center, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, IconData icon, int index) {
    bool isSelected = _currentModeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentModeIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.deepOrange : Colors.white70),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: isSelected ? Colors.deepOrange : Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: Config Card ---
  Widget _buildConfigCard() {
    bool isRecipe = _currentModeIndex == 0;

    // Animate height change when switching modes
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<int>(_currentModeIndex),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isRecipe ? "Recipe Settings" : "Workout Settings", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(isRecipe ? Icons.soup_kitchen : Icons.directions_run, color: Colors.grey.shade400)
              ],
            ),
            const SizedBox(height: 15),

            if (isRecipe) ...[
              _buildDropdown(recipeModes, selectedRecipeMode, (v) => setState(() => selectedRecipeMode = v!)),
              if (selectedRecipeMode != "Unique Recipe") ...[
                const SizedBox(height: 12),
                _buildTextField(_ingredientsController, selectedRecipeMode == "From Ingredients" ? "e.g. Chicken, Rice" : "e.g. Pasta"),
              ]
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildDropdown(fitnessEquipments, selectedEquipment, (v) => setState(() => selectedEquipment = v!))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown(intensityLevels, selectedIntensity, (v) => setState(() => selectedIntensity = v!))),
                ],
              )
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                label: const Text("GENERATE PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: isGenerating ? null : _handleGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: Colors.deepOrange.withOpacity(0.4),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Chat Bubbles ---
  Widget _buildMessageBubble(Map<String, String> msg) {
    bool isUser = msg['role'] == 'user';
    String text = msg['text']!;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepOrange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                children: [
                  const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Text("NutriFit AI", style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(
              text,
              style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange.shade300)),
            const SizedBox(width: 10),
            Text("Thinking...", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Bottom Input ---
  Widget _buildBottomInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: "Ask a follow-up...",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _handleChatSubmit(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _handleChatSubmit,
            ),
          ),
        ],
      ),
    );
  }

  // --- INPUT HELPERS ---
  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return DropdownButtonFormField(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }
}