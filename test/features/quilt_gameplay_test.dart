// Quilt play: the "why is it wrong" message, the live preview, the two-step teaching
// hint (through the real play screen) and the finishing merge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/features/boards/quilt_board.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

QuiltPuzzle levelPuzzle() =>
    generatePuzzle(LevelConfig.forLevel(GameId.quilt, 12)) as QuiltPuzzle;

/// A rectangle of at least two squares with the given fault, found by search.
QuiltRect rectWith(QuiltPuzzle p, QuiltFaultKind kind) {
  for (var row = 0; row < p.size; row++) {
    for (var col = 0; col < p.size; col++) {
      for (var h = 1; row + h <= p.size; h++) {
        for (var w = 1; col + w <= p.size; w++) {
          final r = QuiltRect(row: row, col: col, width: w, height: h);
          if (r.area > 1 && QuiltRules.fault(p, r)?.kind == kind) return r;
        }
      }
    }
  }
  throw StateError('no $kind rectangle');
}

/// Drags across [r] on the board (corner to corner), optionally leaving the finger down.
Future<TestGesture?> drag(
  WidgetTester tester,
  QuiltPuzzle p,
  QuiltRect r, {
  bool hold = false,
}) async {
  final paint = find
      .descendant(
        of: find.byType(QuiltBoard),
        matching: find.byType(CustomPaint),
      )
      .first;
  final box = tester.getRect(paint);
  final cell = box.width / p.size;
  Offset centre(int row, int col) =>
      box.topLeft + Offset(col * cell + cell / 2, row * cell + cell / 2);
  final g = await tester.startGesture(centre(r.row, r.col));
  await tester.pump(const Duration(milliseconds: 20));
  await g.moveTo(centre(r.row + r.height - 1, r.col + r.width - 1));
  await tester.pump(const Duration(milliseconds: 20));
  if (hold) return g;
  await g.up();
  await tester.pump(const Duration(milliseconds: 250));
  return null;
}

void main() {
  test(
    'controller: a wrong patch carries its fault, a right one clears it',
    () {
      final p = levelPuzzle();
      final c = QuiltController(p);
      final stray = rectWith(p, QuiltFaultKind.noClue);
      c.startDrag(stray.row * p.size + stray.col);
      c.updateDrag(
        (stray.row + stray.height - 1) * p.size + stray.col + stray.width - 1,
      );
      expect(c.endDrag(), 1);
      expect(c.fault!.kind, QuiltFaultKind.noClue);
      expect(c.faultRect, stray);

      c.dismissFault();
      expect(c.fault, isNull);

      // Stitching the real patch of a clue clears the message.
      final good = p.solution.first;
      c.startDrag(good.row * p.size + good.col);
      c.updateDrag(
        (good.row + good.height - 1) * p.size + good.col + good.width - 1,
      );
      c.endDrag();
      expect(c.fault, isNull);
    },
  );

  test('controller: hint takes wrong patches off, then points, then stitches for free', () {
    final p = levelPuzzle();
    final c = QuiltController(p);
    final good = p.solution.first;
    final stray = rectWith(p, QuiltFaultKind.noClue);
    c.placed = [good, stray];

    // 1. Mistakes first — the correct patch stays.
    final first = c.hint()!;
    expect(first.text, contains("didn't belong"));
    expect(c.placed, [good]);
    expect(c.hintPending, isFalse);
    c.undo();
    expect(c.placed, [
      good,
      stray,
    ], reason: 'undo brings the removed patch back');

    // 2. No mistakes: one clue glows and the reason is given; nothing is placed yet.
    c.placed = [good];
    final look = c.hint()!;
    expect(look.text, startsWith('Look at the glowing clue'));
    expect(look.actionLabel, 'Show me');
    expect(look.free, isFalse);
    expect(c.hintPending, isTrue);
    expect(c.spotlightClue, isNotNull);
    expect(c.placed, [good]);

    // 3. Pressing Hint again stitches it — and says it is free.
    final plan = QuiltRules.hintPlan(p, [good])!;
    final done = c.hint()!;
    expect(done.free, isTrue);
    expect(c.placed, contains(plan.rect));
    expect(c.hintRect, plan.rect);
    expect(c.hintPending, isFalse);
    expect(c.spotlightClue, isNull);
  });

  test('controller: "Show me" places the patch; moving on cancels the pending hint', () {
    final p = levelPuzzle();
    final c = QuiltController(p);
    final look = c.hint()!;
    final shown = look.onAction!()!;
    expect(shown.text, contains('Stitched'));
    expect(c.placed.length, 1);

    final c2 = QuiltController(p);
    c2.hint();
    expect(c2.hintPending, isTrue);
    c2.startDrag(0); // the player ignores the hint and draws
    expect(c2.hintPending, isFalse);
    expect(c2.spotlightClue, isNull);
  });

  testWidgets(
    'a wrong patch is hatched and a message says why; ✕ dismisses it',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.quilt, 12));
      final p = levelPuzzle();
      final stray = rectWith(p, QuiltFaultKind.noClue);
      final held = await drag(tester, p, stray, hold: true);
      await tester.pump(const Duration(milliseconds: 100));
      await capture(tester, 'quilt_a_preview_neutral');
      await held!.up();
      await settle(tester, frames: 4);

      expect(
        find.text(
          'This patch has no clue. Every patch wraps exactly one clue.',
        ),
        findsOneWidget,
      );
      await capture(tester, 'quilt_b_wrong_patch');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, frames: 4);
      expect(find.textContaining('has no clue'), findsNothing);
      expect(find.text('Wide'), findsOneWidget, reason: 'the legend is back');
      await closeApp(tester, c);
    },
  );

  testWidgets('a right drag previews in the clue colour', (tester) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.quilt, 12));
    final p = levelPuzzle();
    final held = await drag(tester, p, p.solution.first, hold: true);
    await tester.pump(const Duration(milliseconds: 100));
    await capture(tester, 'quilt_c_preview_valid');
    await held!.up();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('has no clue'), findsNothing);
    await closeApp(tester, c);
  });

  testWidgets('Hint → spotlight + reason + Show me; the hint is spent once', (
    tester,
  ) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.quilt, 12));
    final save = c.read(saveProvider.notifier);
    final before = save.economyNow.hints;

    await tester.tap(find.text('Hint'));
    await settle(tester, frames: 4);
    expect(find.textContaining('Look at the glowing clue'), findsOneWidget);
    expect(find.text('Show me'), findsOneWidget);
    expect(save.economyNow.hints, before - 1);
    await capture(tester, 'quilt_d_hint_spotlight');

    await tester.tap(find.text('Show me'));
    await settle(tester, frames: 4);
    expect(find.text('Show me'), findsNothing);
    expect(find.textContaining('Stitched a'), findsOneWidget);
    expect(
      save.economyNow.hints,
      before - 1,
      reason: 'showing the answer is free',
    );
    expect(
      find.text('1 of ${levelPuzzle().clues.length} patches'),
      findsOneWidget,
    );
    await capture(tester, 'quilt_e_hint_placed');
    await closeApp(tester, c);
  });

  testWidgets('with no hints left, "Show me" is still free', (tester) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.quilt, 12));
    final save = c.read(saveProvider.notifier);
    while (save.economyNow.hints > 1) {
      save.spendHint();
    }
    await tester.tap(find.text('Hint'));
    await settle(tester, frames: 4);
    expect(save.economyNow.hints, 0);
    // Hint pressed again with 0 left finishes the step instead of asking for an ad.
    await tester.tap(find.text('Hint'));
    await settle(tester, frames: 4);
    expect(find.text('No hints left'), findsNothing);
    expect(find.textContaining('Stitched a'), findsOneWidget);
    await closeApp(tester, c);
  });

  testWidgets('solving the grid merges the patches (win animation completes)', (
    tester,
  ) async {
    final c = await pumpApp(tester, route: Routes.play(GameId.quilt, 12));
    final board = tester.widget<QuiltBoard>(find.byType(QuiltBoard)).controller;
    board.placed = [...board.puzzle.solution];
    board.dragFrom = board.dragTo = null;
    board.startDrag(0); // nudge a rebuild + listener round
    board.placed = [...board.puzzle.solution];
    board.dragFrom = board.dragTo = null;
    await settle(tester, frames: 5);
    await capture(tester, 'quilt_f_win_end');
    await closeApp(tester, c);
  });
}
