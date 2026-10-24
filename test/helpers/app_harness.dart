// Pumps the real app (router, theme, providers) on a temp save store with a
// fixed clock, starting at any route. Not a test file (no _test suffix).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/app.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/core/storage/save_store.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import 'screen_capture.dart';

final testNow = DateTime(2026, 10, 22, 20, 15);

/// A player part-way through: Thread at level 34, a streak, some achievements.
SaveData sampleSave({
  ThemeChoice theme = ThemeChoice.day,
  Set<String> tips = const {
    'coach',
    'howto_thread',
    'howto_quilt',
    'howto_twist',
    'howto_sudoku',
    'howto_sleuth',
    'howto_bridges',
  },
}) {
  final attempts = <Attempt>[];
  final levels = <GameId, Map<int, LevelRecord>>{};
  var t = testNow.subtract(const Duration(days: 40)).millisecondsSinceEpoch;
  void solve(GameId g, int l, int secs, int stars, {int hints = 0}) {
    t += 1000 * 60 * 60 * 3;
    attempts.add(
      Attempt(
        game: g,
        level: l,
        at: t,
        solved: true,
        seconds: secs,
        hints: hints,
        stars: stars,
      ),
    );
    (levels[g] ??= {})[l] = LevelRecord(
      stars: stars,
      bestSeconds: secs,
      noHint: hints == 0,
      solvedAt: t,
    );
  }

  for (var l = 1; l <= 33; l++) {
    solve(
      GameId.thread,
      l,
      40 + (l * 7) % 50,
      l % 5 == 0 ? 2 : 3,
      hints: l % 9 == 0 ? 1 : 0,
    );
  }
  for (var l = 1; l <= 11; l++) {
    solve(GameId.quilt, l, 35 + l * 3, 3);
  }
  for (var l = 1; l <= 20; l++) {
    solve(GameId.twist, l, 50 + l * 2, l % 4 == 0 ? 2 : 3);
  }
  for (var l = 1; l <= 17; l++) {
    solve(GameId.sudoku, l, 70 + l * 3, 3);
  }
  // Recent days for the streak and the week chart.
  for (var d = 6; d >= 0; d--) {
    final at = testNow
        .subtract(Duration(days: d, hours: 1))
        .millisecondsSinceEpoch;
    attempts.add(
      Attempt(
        game: GameId.values[d % 4],
        level: 1,
        at: at,
        solved: true,
        seconds: 60 + d * 5,
        stars: 3,
        daily: true,
      ),
    );
  }
  return SaveData(
    profile: const Profile(name: 'Sam', badge: 0, onboarded: true),
    settings: AppSettings(theme: theme, sound: false, haptics: false),
    economy: Economy(
      lives: 3,
      hints: 5,
      hintDay: '2026-10-22',
      livesStampMs: testNow.millisecondsSinceEpoch,
    ),
    games: {
      for (final e in levels.entries)
        e.key: GameProgress(
          levels: e.value,
          chestsOpened: {
            for (final l in e.value.keys)
              if (l % 15 == 0) l,
          },
        ),
    },
    attempts: attempts,
    achievements: {
      'first_solve': t,
      'island_hopper': t,
      'path_finder': t,
      'week_streak': t,
    },
    xp: 2340,
    seenTips: tips,
    ads: const AdPacing(sessions: 5),
  );
}

/// Pumps the app at [route]. Call [closeApp] at the end of the test.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required String route,
  SaveData? save,
  Object? extra,
}) async {
  usePhoneView(tester);
  await loadAppFonts();
  clearPuzzleCache();
  final dir = Directory.systemTemp.createTempSync('mi_app');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(SaveStore(dir)),
      initialSaveProvider.overrideWithValue(save ?? sampleSave()),
      clockProvider.overrideWithValue(() => testNow),
      initialRouteProvider.overrideWithValue(
        extra == null ? route : Routes.home,
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: capturable(const MindIslesApp()),
    ),
  );
  if (extra != null) {
    await tester.pump();
    container.read(routerProvider).push(route, extra: extra);
  }
  await settle(tester);
  return container;
}

/// Lets entrance animations and async generation finish (never waits for loops).
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Unmounts the app and disposes providers so no timers outlive the test.
Future<void> closeApp(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  c.dispose();
  await tester.pump(const Duration(seconds: 1));
}
