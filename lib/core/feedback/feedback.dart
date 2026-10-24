// Sound effects + haptics behind one small service that respects Settings.
//
// Why a pool: game moves fire sounds quickly (path steps, pops); a few
// low-latency players avoid cutting each other off. Sounds mix with the
// player's own music and stay silent when the phone is on silent (iOS).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/save_controller.dart';

enum Sfx { tap, step, place, word, hint, error, lose, star, solve, chest }

class FeedbackService {
  FeedbackService(this._ref);
  final Ref _ref;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
          respectSilence: true,
        ).build(),
      );
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
    } catch (_) {
      // Audio is a nicety; never let it break play (e.g. in widget tests).
    }
  }

  /// Plays a sound if sound effects are on.
  Future<void> play(Sfx s, {double volume = .8}) async {
    if (!_ref.read(settingsProvider).sound) return;
    await _init();
    if (_pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/${s.name}.wav'), volume: volume);
    } catch (_) {}
  }

  void _haptic(void Function() f) {
    if (_ref.read(settingsProvider).haptics) f();
  }

  /// Light tick for taps and path steps.
  void tick() => _haptic(HapticFeedback.selectionClick);

  /// Medium bump for placing a piece or finding a word.
  void bump() => _haptic(HapticFeedback.lightImpact);

  /// Heavy thud for losing a life or a wrong move.
  void thud() => _haptic(HapticFeedback.heavyImpact);

  /// Celebration pattern.
  Future<void> celebrate() async {
    if (!_ref.read(settingsProvider).haptics) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }
}

final feedbackProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref),
);
