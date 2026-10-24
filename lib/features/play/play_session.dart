// The clock and counters of one attempt: active time (pauses don't count),
// the per-life countdown, lives lost and hints used.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/level_config.dart';

class PlaySession extends ChangeNotifier {
  PlaySession({required this.spec, required this.relaxed, required this.onTimeUp}) : clockLeft = spec.clockSeconds;

  final LevelSpec spec;
  final bool relaxed;
  final VoidCallback onTimeUp;

  int elapsed = 0;
  int clockLeft;
  int livesLost = 0;
  int hintsUsed = 0;
  bool paused = true;
  bool over = false;
  Timer? _timer;

  double get clockFraction => relaxed ? 1 : (clockLeft / spec.clockSeconds).clamp(0, 1);

  void start() {
    paused = false;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    if (paused) return;
    paused = true;
    notifyListeners();
  }

  void resume() {
    if (over) return;
    start();
  }

  void freshClock() {
    clockLeft = spec.clockSeconds;
    notifyListeners();
  }

  void finish() {
    over = true;
    paused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void _tick() {
    if (paused || over) return;
    elapsed++;
    if (!relaxed) {
      clockLeft--;
      if (clockLeft <= 0) {
        clockLeft = 0;
        paused = true;
        notifyListeners();
        onTimeUp();
        return;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
