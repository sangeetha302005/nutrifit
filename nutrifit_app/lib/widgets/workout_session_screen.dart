// lib/screens/workout_session_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback
import '../widgets/fitness_tab.dart'; // Ensure this path matches where your Exercise class is

class WorkoutSessionScreen extends StatefulWidget {
  final List<Exercise> exercises;
  final int totalDurationMinutes;

  const WorkoutSessionScreen({
    super.key,
    required this.exercises,
    required this.totalDurationMinutes,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with TickerProviderStateMixin {
  // Navigation State
  int _currentExerciseIndex = 0;
  int _currentSet = 1;

  // Timer State
  bool _isResting = false;
  bool _isPaused = false;
  Timer? _timer;

  // Counters
  int _countdownSeconds = 0; // Current active countdown (for rest or timed exercise)
  int _maxCountdownSeconds = 1; // To calculate progress percentage
  int _totalElapsedSeconds = 0; // Total workout time
  Timer? _totalTimer;

  @override
  void initState() {
    super.initState();
    _startTotalTimer();
    _initSet();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _totalTimer?.cancel();
    super.dispose();
  }

  // --- TIMERS ---

  void _startTotalTimer() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused) {
        setState(() => _totalElapsedSeconds++);
      }
    });
  }

  void _initSet() {
    final currentExercise = widget.exercises[_currentExerciseIndex];
    _timer?.cancel();

    if (currentExercise.isTime) {
      // It's a timed exercise (e.g. Plank)
      setState(() {
        _isResting = false;
        _maxCountdownSeconds = currentExercise.repLow; // Use low range as target
        _countdownSeconds = _maxCountdownSeconds;
      });
      _startCountdown();
    } else {
      // It's a rep exercise (e.g. Pushups) - No auto countdown, just waiting for "Done"
      setState(() {
        _isResting = false;
        _countdownSeconds = 0;
        _maxCountdownSeconds = 1; // Avoid divide by zero
      });
    }
  }

  void _startRest() {
    HapticFeedback.mediumImpact(); // Tactile feedback
    setState(() {
      _isResting = true;
      _maxCountdownSeconds = 30; // 30s rest default
      _countdownSeconds = _maxCountdownSeconds;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (_isResting) {
          // Rest finished -> Go to next set/exercise
          _advanceWorkout();
        } else {
          // Timed exercise finished -> Go to rest
          _startRest();
        }
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  // --- LOGIC ---

  void _onMainButtonPressed() {
    if (_isResting) {
      // Skip Rest
      _timer?.cancel();
      _advanceWorkout();
    } else {
      // Finish Set
      final currentExercise = widget.exercises[_currentExerciseIndex];
      if (currentExercise.isTime) {
        // If it was timed, we are skipping the remaining time
        _timer?.cancel();
      }
      _startRest();
    }
  }

  void _advanceWorkout() {
    final currentExercise = widget.exercises[_currentExerciseIndex];

    if (_currentSet < currentExercise.sets) {
      // Next Set same exercise
      setState(() {
        _currentSet++;
        _initSet();
      });
    } else {
      // Next Exercise
      if (_currentExerciseIndex < widget.exercises.length - 1) {
        setState(() {
          _currentExerciseIndex++;
          _currentSet = 1;
          _initSet();
        });
      } else {
        _finishWorkout();
      }
    }
  }

  void _finishWorkout() {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    _totalTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.orange, size: 50),
            SizedBox(height: 10),
            Text("Workout Complete!"),
          ],
        ),
        content: Text(
          "You crushed it in ${_formatDuration(_totalElapsedSeconds)}!",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text("FINISH", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ================= UI BUILD =================

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) return const Scaffold(body: Center(child: Text("Empty Workout")));

    // Theme Colors based on state
    final themeColor = _isResting ? Colors.blueAccent : Colors.deepOrangeAccent;
    final bgColor = _isResting ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0);

    final currentExercise = widget.exercises[_currentExerciseIndex];

    // Identify next exercise for "Up Next" preview
    Exercise? nextExercise;
    if (_isResting) {
      if (_currentSet < currentExercise.sets) {
        nextExercise = currentExercise; // Next is same exercise
      } else if (_currentExerciseIndex < widget.exercises.length - 1) {
        nextExercise = widget.exercises[_currentExerciseIndex + 1];
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar (Pause & Total Time)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          _formatDuration(_totalElapsedSeconds),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    onPressed: _togglePause,
                  ),
                ],
              ),
            ),

            // 2. Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- IMAGE SECTION ---
                    if (!_isResting)
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                            ],
                            image: DecorationImage(
                              image: AssetImage(currentExercise.assetImage ?? "assets/default.png"),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                    if (_isResting) const Spacer(),

                    const SizedBox(height: 30),

                    // --- TITLE SECTION ---
                    Text(
                      _isResting ? "REST" : currentExercise.name,
                      style: TextStyle(
                        fontSize: _isResting ? 40 : 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (!_isResting) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Set $_currentSet of ${currentExercise.sets}",
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // --- TIMER / REPS SECTION ---
                    if (_isResting || currentExercise.isTime)
                      _buildCircularTimer(themeColor)
                    else
                    // Just show Reps count for non-timed exercises
                      Column(
                        children: [
                          Text(
                            "${currentExercise.repLow}-${currentExercise.repHigh}",
                            style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: themeColor),
                          ),
                          const Text("REPS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),

                    // --- UP NEXT PREVIEW (Only during Rest) ---
                    if (_isResting && nextExercise != null)
                      Container(
                        margin: const EdgeInsets.only(top: 30),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("UP NEXT: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text(nextExercise.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),

                    if (_isResting) const Spacer(),
                  ],
                ),
              ),
            ),

            // 3. Bottom Controls
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _onMainButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        elevation: 5,
                        shadowColor: themeColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _isResting ? "SKIP REST" : (currentExercise.isTime ? "FINISH EXERCISE" : "COMPLETE SET"),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Circular Timer ---
  Widget _buildCircularTimer(Color color) {
    double progress = _countdownSeconds / _maxCountdownSeconds;

    return SizedBox(
      height: 160,
      width: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ring
          SizedBox(
            height: 160, width: 160,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              valueColor: AlwaysStoppedAnimation(color.withOpacity(0.1)),
            ),
          ),
          // Progress Ring
          SizedBox(
            height: 160, width: 160,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          // Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$_countdownSeconds",
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: color),
              ),
              const Text("SEC", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}