// Pumps every main screen with sample data, checks key content, and writes
// build/screens/*.png for a visual review (no device needed).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

void main() {
  Future<void> shot(WidgetTester tester, String route, String name, {SaveData? save, Object? extra, String? expectText}) async {
    final c = await pumpApp(tester, route: route, save: save, extra: extra);
    if (route == Routes.result) await settle(tester, frames: 20);
    if (expectText != null) expect(find.textContaining(expectText), findsWidgets);
    await capture(tester, name);
    await closeApp(tester, c);
  }

  testWidgets('welcome', (t) => shot(t, Routes.welcome, '01_welcome', save: const SaveData(), expectText: 'Welcome aboard'));
  testWidgets('try puzzle', (t) => shot(t, Routes.tryPuzzle, '02_try', save: const SaveData(), expectText: 'Draw one thread'));
  testWidgets('pick island', (t) => shot(t, Routes.pickIsland, '03_pick_island', save: const SaveData(), expectText: 'Where should we land'));
  testWidgets('profile', (t) => shot(t, Routes.profile, '04_profile', save: const SaveData(), expectText: 'Make it yours'));
  testWidgets('home', (t) => shot(t, Routes.home, '05_home', expectText: 'Your islands'));
  testWidgets('home night', (t) => shot(t, Routes.home, '05b_home_night', save: sampleSave(theme: ThemeChoice.night)));
  testWidgets('island', (t) => shot(t, Routes.island(GameId.thread), '06_island', expectText: 'Play level 34'));
  testWidgets('play thread', (t) => shot(t, Routes.play(GameId.thread, 34), '07_thread', expectText: 'Level 34'));
  testWidgets('play quilt', (t) => shot(t, Routes.play(GameId.quilt, 12), '08_quilt', expectText: 'patches'));
  testWidgets('play twist', (t) => shot(t, Routes.play(GameId.twist, 21), '09_twist', expectText: 'Theme'));
  testWidgets('play sudoku', (t) => shot(t, Routes.play(GameId.sudoku, 18), '10_sudoku', expectText: 'left'));
  testWidgets('play sudoku night', (t) => shot(t, Routes.play(GameId.sudoku, 18), '10b_sudoku_night', save: sampleSave(theme: ThemeChoice.night)));
  testWidgets('first level tips', (t) => shot(t, Routes.play(GameId.thread, 1), '11_coach', save: sampleSave(tips: const {'howto_thread'}), expectText: 'TIP 1 OF 3'));
  testWidgets('insights', (t) => shot(t, Routes.insights, '12_insights', expectText: 'Puzzles solved per day'));
  testWidgets('game insights', (t) => shot(t, Routes.gameInsights(GameId.thread), '13_game_insights', expectText: 'Solve time'));
  testWidgets('achievements', (t) => shot(t, Routes.achievements, '14_achievements', expectText: 'unlocked'));
  testWidgets('settings', (t) => shot(t, Routes.settings, '15_settings', expectText: 'Theme'));
  testWidgets('backup', (t) => shot(t, Routes.backup, '16_backup', expectText: 'Back up now'));
  testWidgets('out of lives', (t) {
    final s = sampleSave();
    return shot(t, Routes.outOfLives, '17_out_of_lives',
        save: s.copyWith(economy: Economy(lives: 0, livesStampMs: testNow.subtract(const Duration(minutes: 8)).millisecondsSinceEpoch, hints: 5, hintDay: '2026-10-22')),
        extra: LevelConfig.forLevel(GameId.thread, 34),
        expectText: 'Out of lives');
  });
  testWidgets('result', (t) {
    final spec = LevelConfig.forLevel(GameId.thread, 34);
    final outcome = LevelOutcome(
      spec: spec,
      stars: 3,
      seconds: 78,
      hints: 0,
      livesLost: 0,
      xp: 60,
      firstSolve: true,
      previousBest: null,
      chestHints: 0,
      tierCleared: null,
      newAchievements: const [],
      relaxed: false,
    );
    return shot(t, Routes.result, '18_result', extra: outcome, expectText: 'Level 34 solved!');
  });
}
