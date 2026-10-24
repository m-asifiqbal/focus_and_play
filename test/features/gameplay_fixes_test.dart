// Regression tests for: screen-reader taps, replays with no lives, Sudoku undo
// of hints/reset, Twist's free first letter, Quilt taps, fast-drag sampling and
// the puzzle cache.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/core/theme/app_theme.dart';
import 'package:focus_and_play_mindgame/core/theme/mi_colors.dart';
import 'package:focus_and_play_mindgame/core/widgets/mi_buttons.dart';
import 'package:focus_and_play_mindgame/core/widgets/mi_controls.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/boards/drag_sampling.dart';
import 'package:focus_and_play_mindgame/features/boards/quilt_board.dart';
import 'package:focus_and_play_mindgame/features/boards/sudoku_board.dart';
import 'package:focus_and_play_mindgame/features/boards/twist_board.dart';
import 'package:focus_and_play_mindgame/features/island/map/island_map_view.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku.dart';
import 'package:focus_and_play_mindgame/games/twist/twist.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

void main() {
  // Every page whose toolbar used to scroll away with its content.
  final pinned = <(String, String)>[
    // (route, a text in the toolbar)
    (Routes.home, 'Sam'),
    (Routes.insights, 'Insights'),
    (Routes.settings, 'Settings'),
    (Routes.backup, 'Local backup'),
  ];
  for (final (route, header) in pinned) {
    testWidgets('$route: the toolbar stays put while the page scrolls', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: route);
      final before = tester.getTopLeft(find.text(header).first);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getTopLeft(find.text(header).first),
        before,
        reason: 'header must not move',
      );
      await closeApp(tester, c);
    });
  }

  testWidgets('game insights: the back button stays put while scrolling', (
    tester,
  ) async {
    final c = await pumpApp(tester, route: Routes.gameInsights(GameId.thread));
    final back = find.bySemanticsLabel('Back');
    final before = tester.getTopLeft(back.first);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(back.first), before);
    await closeApp(tester, c);
  });

  testWidgets('switching tabs slides the pages and keeps each tab\'s state', (
    tester,
  ) async {
    final c = await pumpApp(tester, route: Routes.home);
    final homeX = tester.getTopLeft(find.text('Your islands')).dx;
    await tester.tap(find.text('Insights').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Mid-slide: Home is moving out to the left, Insights coming in from the right.
    expect(find.text('Your islands'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Your islands')).dx, lessThan(homeX));
    expect(
      tester.getTopLeft(find.text('Puzzles solved per day')).dx,
      greaterThan(homeX),
    );
    await settle(tester);
    expect(
      find.text('Your islands'),
      findsNothing,
      reason: 'Home is offstage once the slide ends',
    );
    expect(find.text('Puzzles solved per day'), findsOneWidget);
    // Back to Home: it slides in from the left, still mounted (no rebuild from scratch).
    await tester.tap(find.text('Home').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getTopLeft(find.text('Your islands')).dx, lessThan(homeX));
    await settle(tester);
    expect(tester.getTopLeft(find.text('Your islands')).dx, homeX);
    await closeApp(tester, c);
  });

  testWidgets(
    'buttons, icon buttons and switches can be activated by a screen reader',
    (tester) async {
      final handle = tester.ensureSemantics();
      final taps = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialSaveProvider.overrideWithValue(
              const SaveData(
                settings: AppSettings(sound: false, haptics: false),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.build(MiColors.day),
            home: Scaffold(
              body: Column(
                children: [
                  MiButton(label: 'Go', onTap: () => taps.add('Go')),
                  MiIconButton(
                    icon: Icons.close,
                    label: 'Close it',
                    onTap: () => taps.add('Close it'),
                  ),
                  MiSwitch(
                    value: false,
                    label: 'Sw',
                    onChanged: (_) => taps.add('Sw'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in ['Go', 'Close it', 'Sw']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: label);
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
      }
      expect(taps, ['Go', 'Close it', 'Sw']);
      handle.dispose();
    },
  );

  testWidgets(
    'with no lives, a solved level can still be replayed — and never costs a life',
    (tester) async {
      final s = sampleSave();
      final c = await pumpApp(
        tester,
        route: Routes.island(GameId.thread),
        save: s.copyWith(
          economy: Economy(
            lives: 0,
            livesStampMs: testNow.millisecondsSinceEpoch,
            hints: 3,
            hintDay: '2026-10-22',
          ),
        ),
      );
      final pad = find.byWidgetPredicate((w) => w is LevelPad && w.level == 33);
      await Scrollable.ensureVisible(tester.element(pad), alignment: .5);
      await tester.pump();
      await tester.tap(pad);
      await settle(tester);
      expect(find.textContaining('replays never cost a life'), findsOneWidget);
      await tester.tap(find.text('Play again'));
      await settle(tester);
      expect(find.text('Out of lives'), findsNothing);
      expect(find.text('Level 33 · Hard'), findsOneWidget);
      expect(
        find.text('Replay'),
        findsOneWidget,
        reason: 'the HUD shows no hearts at stake',
      );
      await closeApp(tester, c);
    },
  );

  test('Sudoku: undoing a hint clears its highlight; Reset can be undone', () {
    final p = SudokuGenerator.generate(const SudokuParams(givens: 20), 7);
    final c = SudokuController(p);
    final empty = List.generate(36, (i) => i).firstWhere((i) => !c.isGiven(i));
    c.select(empty);
    expect(c.hint(), isNotNull);
    expect(c.hinted, contains(empty));
    c.undo();
    expect(c.values[empty], 0);
    expect(c.hinted, isEmpty);

    c.select(empty);
    c.input(p.solution[empty]);
    c.reset();
    expect(c.values[empty], 0);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.values[empty], p.solution[empty]);
  });

  test(
    'Twist: finding a word reveals the next word\'s first letter for free',
    () {
      final p =
          generatePuzzle(LevelConfig.forLevel(GameId.twist, 5)) as TwistPuzzle;
      final c = TwistController(p);
      // The first word's first letter shows from the start.
      expect(c.revealed[0], 1);
      expect(c.message, 'The first word starts with ${p.words[0].word[0]}');
      c.traced = [...p.words[0].cells];
      expect(c.submit(), 1);
      expect(
        c.revealed[1],
        1,
        reason: 'next unfound word (shortest first) shows its first letter',
      );
      expect(c.message, contains(p.words[1].word[0]));
      expect(c.messageGood, isTrue);

      // Undo takes the free letter back.
      c.undo();
      expect(c.found, isEmpty);
      expect(c.revealed.containsKey(1), isFalse);

      // …unless a hint has built on it since.
      c.traced = [...p.words[0].cells];
      c.submit();
      c.hint();
      expect(c.revealed[1], 2);
      c.undo();
      expect(c.revealed[1], 2);
    },
  );

  testWidgets(
    'Twist board: after a find, the next word\'s first letter shows and glows',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.twist, 21));
      final board = tester
          .widget<TwistBoard>(find.byType(TwistBoard))
          .controller;
      final first = board.puzzle.words[0];
      board.traced = [...first.cells];
      board.submit();
      await settle(tester, frames: 4);
      final next = board.puzzle.words[1].word;
      expect(
        find.text('Nice! The next word starts with ${next[0]}'),
        findsOneWidget,
      );
      expect(board.revealed[1], 1);
      await capture(tester, '09b_twist_free_letter');
      await closeApp(tester, c);
    },
  );

  test('Quilt: a tap on an empty square stitches nothing', () {
    final p =
        generatePuzzle(LevelConfig.forLevel(GameId.quilt, 3)) as QuiltPuzzle;
    final c = QuiltController(p);
    c.startDrag(0);
    expect(c.endDrag(), 0);
    expect(c.placed, isEmpty);
    expect(c.canUndo, isFalse);
  });

  test('a fast drag is filled in so no square in between is skipped', () {
    final pts = pointsAlong(
      const Offset(5, 5),
      const Offset(205, 5),
      10,
    ).toList();
    expect(pts.length, 20);
    expect(pts.last, const Offset(205, 5));
    for (var i = 1; i < pts.length; i++) {
      expect((pts[i] - pts[i - 1]).distance, lessThanOrEqualTo(10.0001));
    }
  });

  test(
    'the puzzle cache hands back the same puzzle for the same level',
    () async {
      clearPuzzleCache();
      final spec = LevelConfig.forLevel(GameId.sudoku, 4);
      final a = await generatePuzzleAsync(spec);
      final b = await generatePuzzleAsync(spec);
      expect(identical(a, b), isTrue);
      expect(a, isA<SudokuPuzzle>());
    },
  );
}
