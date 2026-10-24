// End-to-end flows through the real app: onboarding, solving a level by
// tapping the board, the celebration, the island map and hints.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/boards/thread_board.dart';
import 'package:focus_and_play_mindgame/features/onboarding/try_puzzle_screen.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/thread/thread.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import '../helpers/app_harness.dart';

/// Taps the Thread board's cells in [order].
Future<void> tapCells(WidgetTester tester, int n, List<int> order) async {
  final paint = find.descendant(of: find.byType(ThreadBoard), matching: find.byType(CustomPaint)).first;
  final r = tester.getRect(paint);
  final cell = r.width / n;
  for (final i in order) {
    await tester.tapAt(r.topLeft + Offset((i % n) * cell + cell / 2, (i ~/ n) * cell + cell / 2));
    await tester.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  testWidgets('onboarding: warm-up puzzle, pick an island, profile → level 1 with tips', (tester) async {
    final c = await pumpApp(tester, route: Routes.welcome, save: const SaveData());
    await tester.tap(find.text('Set sail'));
    await settle(tester);
    expect(find.textContaining('Draw one thread'), findsOneWidget);
    await tapCells(tester, 4, warmUpPuzzle().solution);
    await settle(tester);
    expect(find.textContaining("You're a natural"), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Twist'));
    await settle(tester);
    expect(find.text('Start on Crystal Isle'), findsOneWidget);
    await tester.tap(find.text('Start on Crystal Isle'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Riya');
    await tester.tap(find.text("I've played before"));
    await tester.pump();
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await settle(tester, frames: 20);

    final s = c.read(saveProvider);
    expect(s.profile.onboarded, isTrue);
    expect(s.profile.name, 'Riya');
    expect(s.profile.firstGame, GameId.twist);
    expect(s.progress(GameId.twist).current, 16, reason: "played before → Medium is open");
    // First time on Twist: the how-to-play sheet shows first.
    expect(find.textContaining('HOW TO PLAY'), findsOneWidget);
    await tester.tap(find.textContaining("Got it"));
    await settle(tester);
    expect(find.text('TIP 1 OF 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(i < 2 ? 'Next' : "Let's play"));
      await settle(tester, frames: 4);
    }
    expect(find.text('TIP 1 OF 3'), findsNothing);
    expect(c.read(saveProvider).seenTips, containsAll(['coach', 'howto_twist']));
    await closeApp(tester, c);
  });

  testWidgets('solving Thread level 1 by tapping records 3 stars and celebrates', (tester) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.thread, 1), save: sampleSave().copyWith(games: const {}));
    final puzzle = generatePuzzle(LevelConfig.forLevel(GameId.thread, 1)) as ThreadPuzzle;
    await tapCells(tester, puzzle.size, puzzle.solution);
    await settle(tester, frames: 16);
    expect(find.text('Level 1 solved!'), findsOneWidget);
    final rec = c.read(saveProvider).progress(GameId.thread).levels[1];
    expect(rec, isNotNull);
    expect(rec!.stars, 3);
    await settle(tester, frames: 10);
    // A newly earned achievement pops up over the celebration first.
    while (find.text('Collect').evaluate().isNotEmpty) {
      await tester.tap(find.text('Collect'));
      await settle(tester, frames: 6);
    }
    await tester.tap(find.text('Next level'));
    await settle(tester);
    expect(find.text('Level 2 · Easy'), findsOneWidget);
    await closeApp(tester, c);
  });

  testWidgets('a hint spends one hint, lights the next squares and costs the no-hint star', (tester) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.thread, 1), save: sampleSave().copyWith(games: const {}));
    final before = c.read(saveProvider).economy.hints;
    await tester.tap(find.text('Hint'));
    await settle(tester, frames: 4);
    expect(find.textContaining('Follow the glowing squares'), findsOneWidget);
    expect(c.read(saveProvider.notifier).economyNow.hints, before - 1);
    final puzzle = generatePuzzle(LevelConfig.forLevel(GameId.thread, 1)) as ThreadPuzzle;
    await tapCells(tester, puzzle.size, puzzle.solution.skip(1).toList());
    await settle(tester, frames: 16);
    expect(c.read(saveProvider).progress(GameId.thread).levels[1]!.stars, 2);
    await closeApp(tester, c);
  });

  testWidgets('home → island → level sheet → play', (tester) async {
    final c = await pumpApp(tester, route: Routes.home);
    await tester.tap(find.text('Thread').first);
    await settle(tester);
    expect(find.text('Play level 34'), findsOneWidget);
    await tester.tap(find.text('Play level 34'));
    await settle(tester);
    expect(find.text('EARN 3 STARS'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.text('Level 34 · Hard'), findsOneWidget);
    await closeApp(tester, c);
  });

  testWidgets('no lives left → the level sheet opens the out-of-lives screen', (tester) async {
    final s = sampleSave();
    final c = await pumpApp(tester, route: Routes.island(GameId.thread), save: s.copyWith(economy: Economy(lives: 0, livesStampMs: testNow.millisecondsSinceEpoch, hints: 3, hintDay: '2026-10-22')));
    await tester.tap(find.text('Play level 34'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.text('Out of lives'), findsOneWidget);
    expect(find.textContaining('Next life in'), findsOneWidget);
    await closeApp(tester, c);
  });
}
