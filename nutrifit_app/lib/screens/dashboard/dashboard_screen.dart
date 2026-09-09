// lib/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

import '../../widgets/profile_tab.dart';
import '../../widgets/food_tab.dart';
import '../../widgets/ai_tab.dart';
import '../../widgets/fitness_tab.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String username;

  const DashboardScreen({
    super.key,
    required this.username,
    required String gender, // unused but kept for compatibility
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late List<Widget> _tabs;

  bool _loading = false;
  bool _isFemale = false;
  bool _isPregnant = false;
  bool _trackPeriods = false;

  // Mock data for the dashboard visuals (Replace with real data providers later)
  final int _targetCalories = 2200;
  final int _eatenCalories = 1450;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileListener;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack);
    _fadeController.forward();

    _tabs = [
      Builder(builder: (_) => buildHomeTab()), // Home (Index 0)
      const FoodTab(),
      const AITab(),
      const FitnessTab(),
      const ProfileTab(),
    ];

    _listenToProfile();
  }

  /// 🔥 LISTEN LIVE TO PROFILE DATA
  void _listenToProfile() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Safety timeout to prevent infinite loading if Firebase hangs
      Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _loading) {
          setState(() => _loading = false);
        }
      });

      final ref = FirebaseFirestore.instance.collection("profiles").doc(uid);

      _profileListener = ref.snapshots().listen((doc) {
        if (!doc.exists || doc.data() == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final data = doc.data()!;
        final gender = (data["gender"] ?? "").toString().toLowerCase();

        final femaleMap = data["female"] is Map ? data["female"] as Map : {};
        final flags = femaleMap["flags"] is Map ? femaleMap["flags"] as Map : {};

        if (mounted) {
          setState(() {
            _loading = false;
            _isFemale = gender == "female";
            _isPregnant = flags["isPregnant"] == true;
            _trackPeriods = flags["trackPeriods"] == true;
          });
        }
      }, onError: (err) {
        if (mounted) setState(() => _loading = false);
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _profileListener?.cancel();
    super.dispose();
  }

  /// 🔥 UPDATE FEMALE FLAGS
  Future<void> _updateFlag(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection("profiles").doc(uid).set({
      "female": {
        "flags": {key: value}
      }
    }, SetOptions(merge: true));
  }

  /// 🔥 FEMALE SETTINGS SHEET
  void _openFemaleOptions() {
    if (!_isFemale) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool localPreg = _isPregnant;
        bool localPeriod = _trackPeriods;

        return StatefulBuilder(
          builder: (context, update) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Women's Health Settings",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text("Adjust your plan for your body's needs.",
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),

                  // Pregnancy Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: const Text("Pregnancy Mode",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      subtitle: const Text("Folate focus & gentle exercises"),
                      value: localPreg,
                      activeColor: Colors.purple,
                      onChanged: (v) async {
                        update(() {
                          localPreg = v;
                          if (v) localPeriod = false;
                        });
                        await _updateFlag("isPregnant", v);
                        await _updateFlag("trackPeriods", false);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Period Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: const Text("Cycle Tracking",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                      subtitle: const Text("Iron focus & symptom relief"),
                      value: localPeriod,
                      activeColor: Colors.pink,
                      onChanged: (v) async {
                        update(() {
                          localPeriod = v;
                          if (v) localPreg = false;
                        });
                        await _updateFlag("trackPeriods", v);
                        await _updateFlag("isPregnant", false);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // 🏡 HOME TAB UI
  // ---------------------------------------------------------
  String getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget buildHomeTab() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Section
            _buildHeader(),

            const SizedBox(height: 20),

            // 2. Calorie Progress Ring
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCaloriesCard(),
            ),

            const SizedBox(height: 25),

            // 3. Quick Actions Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Actions",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.qr_code_scanner,
                          label: "Scan Food",
                          color1: Colors.orangeAccent,
                          color2: Colors.deepOrange,
                          onTap: () => _onItemTapped(1),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.fitness_center,
                          label: "Start Workout",
                          color1: Colors.blueAccent,
                          color2: Colors.blue.shade800,
                          onTap: () => _onItemTapped(3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 4. Weight Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Weight Analysis",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("Weekly", style: TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildChart(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader() {
    final userProv = Provider.of<UserProvider>(context);
    final String displayName = userProv.name.isNotEmpty && userProv.name != "NutriFit User"
        ? userProv.name
        : (widget.username.isNotEmpty ? widget.username : "NutriFit User");

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getGreeting(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Profile or Settings Icon
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Horizontal Day Selector
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)).add(Duration(days: index));
                final isToday = date.day == DateTime.now().day;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 50,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.white : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ["M", "T", "W", "T", "F", "S", "S"][date.weekday - 1],
                        style: TextStyle(
                          color: isToday ? Colors.deepOrange : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: isToday ? Colors.deepOrange : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CALORIES RING WIDGET ---
  Widget _buildCaloriesCard() {
    final userProv = Provider.of<UserProvider>(context);
    final int targetCal = userProv.targetCalories > 0 ? userProv.targetCalories : _targetCalories;
    final double eatenCal = userProv.eatenCalories;
    final int remaining = (targetCal - eatenCal).toInt().clamp(0, 99999);
    final double progress = (eatenCal / targetCal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Radial Chart
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        value: progress * 100,
                        color: Colors.deepOrange,
                        radius: 12,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: (1.0 - progress) * 100,
                        color: Colors.grey.shade100,
                        radius: 12,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange.shade400, size: 28),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Calories Remaining", style: TextStyle(color: Colors.grey)),
                Row(
                  children: [
                    Text(
                      "$remaining",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const Text(" kcal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Eaten: ${eatenCal.toInt()} kcal", style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                    Text("Target: $targetCal kcal", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- QUICK ACTION BUTTON ---
  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color2.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- CHART WIDGET ---
  Widget _buildChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 200,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.grey.shade100, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  const days = ["M", "T", "W", "T", "F", "S", "S"];
                  if (value.toInt() >= 0 && value.toInt() < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(days[value.toInt()], style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const Text("");
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 65),
                FlSpot(1, 64.5),
                FlSpot(2, 64.8),
                FlSpot(3, 64.2),
                FlSpot(4, 63.9),
                FlSpot(5, 64.0),
                FlSpot(6, 63.5),
              ],
              isCurved: true,
              color: Colors.deepOrange,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.deepOrange.withOpacity(0.3), Colors.deepOrange.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: (_selectedIndex == 0 && _isFemale)
          ? FloatingActionButton(
              onPressed: _openFemaleOptions,
              backgroundColor: (_isPregnant || _trackPeriods) ? Colors.pinkAccent : Colors.grey.shade800,
              child: const Icon(Icons.favorite, color: Colors.white),
            )
          : null,

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _tabs,
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)
          ]
        ),
        child: BottomNavigationBar(
          selectedItemColor: Colors.deepOrange,
          unselectedItemColor: Colors.grey.shade400,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: "Food"),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_rounded), label: "AI"),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: "Fitness"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }
}