// Sleuth and Bridges through the real play screen: picking, guessing, building,
// hints, losing a round, solving. Also writes screenshots of both boards (day and
// night, mid-game) to build/screens for a visual check.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/boards/bridges_board.dart';
import 'package:focus_and_play_mindgame/features/boards/sleuth_board.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

SleuthPuzzle sleuthPuzzle([int level = 18]) =>
    generatePuzzle(LevelConfig.forLevel(GameId.sleuth, level)) as SleuthPuzzle;

BridgesPuzzle bridgesPuzzle([int level = 18]) =>
    generatePuzzle(LevelConfig.forLevel(GameId.bridges, level))
        as BridgesPuzzle;

SleuthController sleuthOf(WidgetTester t) =>
    t.widget<SleuthBoard>(find.byType(SleuthBoard)).controller;

BridgesController bridgesOf(WidgetTester t) =>
    t.widget<BridgesBoard>(find.byType(BridgesBoard)).controller;

/// The words of the list that are not the secret, in list order.
List<int> wrongWords(SleuthPuzzle p) => [
  for (var i = 0; i < p.words.length; i++)
    if (i != p.secret) i,
];

/// The drawing surface of the Bridges board and the size of one grid cell.
(Rect, double) bridgesArea(WidgetTester t, BridgesPuzzle p) {
  final paint = find
      .descendant(
        of: find.byType(BridgesBoard),
        matching: find.byType(CustomPaint),
      )
      .first;
  final box = t.getRect(paint);
  return (box, box.width / p.cols);
}

Offset isletCentre(Rect box, double cell, BridgesPuzzle p, int i) =>
    box.topLeft +
    Offset((p.islands[i].col + .5) * cell, (p.islands[i].row + .5) * cell);

/// A tap on the gap between two islets, [along] of the way from `a` to `b`.
Future<void> tapGap(
  WidgetTester t,
  BridgesPuzzle p,
  int a,
  int b, {
  double along = .5,
}) async {
  final (box, cell) = bridgesArea(t, p);
  final from = isletCentre(box, cell, p, a), to = isletCentre(box, cell, p, b);
  await t.tapAt(from + (to - from) * along);
  await t.pump(const Duration(milliseconds: 120));
}

/// The first Medium level with two bridges that would cross.
const crossingLevel = 16;

((int, int), (int, int)) crossingPairs(BridgesPuzzle p) {
  for (final x in p.graph.pairs) {
    for (final y in p.graph.pairs) {
      if (x != y && BridgesRules.cross(p, x.$1, x.$2, y.$1, y.$2)) {
        return (x, y);
      }
    }
  }
  throw StateError('no crossing pair on this level');
}

/// How far along [tapped] to press so the finger is as far from [other] as it can be
/// (the board picks the nearest bridge, and at the crossing both are equal).
double clearOfCrossing(BridgesPuzzle p, (int, int) tapped, (int, int) other) {
  Offset at(int i) => Offset(p.islands[i].col + .5, p.islands[i].row + .5);
  double dist(Offset q, Offset a, Offset b) {
    final ab = b - a;
    final t =
        (((q - a).dx * ab.dx + (q - a).dy * ab.dy) /
                (ab.dx * ab.dx + ab.dy * ab.dy))
            .clamp(0.0, 1.0);
    return (q - (a + ab * t)).distance;
  }

  var best = .5, bestD = -1.0;
  for (final t in [.3, .4, .5, .6, .7]) {
    final q = at(tapped.$1) + (at(tapped.$2) - at(tapped.$1)) * t;
    final d = dist(q, at(other.$1), at(other.$2));
    if (d > bestD) {
      bestD = d;
      best = t;
    }
  }
  return best;
}

/// Screen-reader nodes whose label matches [label]. (`find.bySemanticsLabel` only
/// sees nodes owned by a widget, not the ones a painter adds.)
List<SemanticsNode> semanticsLabelled(WidgetTester t, Pattern label) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    if (n.getSemanticsData().label.contains(label)) out.add(n);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return out;
}

void main() {
  group('Sleuth controller', () {
    test('pick, unpick, guess, and the guess is remembered', () {
      final p = sleuthPuzzle();
      final c = SleuthController(p);
      final w = wrongWords(p).first;
      c.pick(w);
      expect(c.picked, w);
      c.pick(w);
      expect(c.picked, isNull, reason: 'tapping again unpicks');
      expect(c.submit(), isNull, reason: 'nothing picked, nothing guessed');

      c.pick(w);
      final marks = c.submit()!;
      expect(marks, hasLength(p.length));
      expect(c.history, hasLength(1));
      expect(c.picked, isNull);
      expect(c.wasGuessed(w), isTrue);
      c.pick(w);
      expect(c.picked, isNull, reason: 'a tried word is not picked twice');
      expect(c.solved, isFalse);
    });

    test('guessing the secret solves it; running out of guesses fails it', () {
      final p = sleuthPuzzle();
      final win = SleuthController(p)..pick(p.secret);
      win.submit();
      expect(win.solved, isTrue);
      expect(win.failMessage, isNull);

      final lose = SleuthController(p);
      for (final w in wrongWords(p).take(p.tries)) {
        lose.pick(w);
        lose.submit();
      }
      expect(lose.solved, isFalse);
      expect(lose.outOfTries, isTrue);
      expect(lose.failMessage, 'The word was ${p.answer}.');
      expect(lose.canHint, isFalse);
      lose.pick(p.secret);
      expect(lose.picked, isNull, reason: 'the round is over');
    });

    test('long-press strikes a word out and back', () {
      final p = sleuthPuzzle();
      final c = SleuthController(p);
      final w = wrongWords(p).first;
      c.toggleStrike(w);
      expect(c.isCrossedOut(w), isTrue);
      c.toggleStrike(w);
      expect(c.isCrossedOut(w), isFalse);
    });

    test(
      'hint picks a word that is still possible and the secret stays hidden',
      () {
        final p = sleuthPuzzle();
        final c = SleuthController(p);
        final note = c.hint()!;
        expect(c.picked, isNotNull);
        expect(c.hinted, c.picked);
        expect(note.text, contains(p.words[c.picked!]));
        expect(note.free, isFalse);
      },
    );

    test('restart: same list, new secret, clean board', () {
      final p = sleuthPuzzle();
      final c = SleuthController(p);
      c.pick(wrongWords(p).first);
      c.submit();
      final before = c.puzzle.secret;
      c.reset();
      expect(c.history, isEmpty);
      expect(c.guessCount, 0);
      expect(c.puzzle.words, p.words);
      expect(c.puzzle.secret, isNot(before));
      final run = SleuthRules.greedyRun(c.puzzle);
      expect(run.last.isCorrect, isTrue);
      expect(run.length, lessThanOrEqualTo(p.tries));
    });
  });

  group('Bridges controller', () {
    test('a tap cycles none → one → two → none', () {
      final p = bridgesPuzzle();
      final c = BridgesController(p);
      final (a, b) = c.pairs.first;
      expect(c.cycle(a, b), isTrue);
      expect(c.bridgesBetween(a, b), 1);
      expect(c.cycle(a, b), isTrue);
      expect(c.bridgesBetween(a, b), 2);
      expect(c.cycle(a, b), isTrue);
      expect(c.bridgesBetween(a, b), 0);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.bridgesBetween(a, b), 2);
    });

    test(
      'a bridge cannot cross another: nothing changes and a message says why',
      () {
        final p = bridgesPuzzle(crossingLevel);
        final c = BridgesController(p);
        final (first, second) = crossingPairs(p);
        expect(c.cycle(first.$1, first.$2), isTrue);
        expect(c.cycle(second.$1, second.$2), isFalse);
        expect(c.bridgesBetween(second.$1, second.$2), 0);
        expect(c.message, "A bridge can't cross another one.");
        expect(
          c.blockedBy,
          first,
          reason: 'the board shows which bridge blocks',
        );
        expect(c.blockedTry, second);
        c.dismissMessage();
        expect(c.message, isNull);
        expect(c.blockedBy, isNull);
      },
    );

    test('the answer solves it; every number is met only then', () {
      final p = bridgesPuzzle();
      final c = BridgesController(p);
      expect(c.solved, isFalse);
      for (final l in p.solution) {
        for (var k = 0; k < l.count; k++) {
          c.cycle(l.a, l.b);
        }
      }
      expect(c.solved, isTrue);
      expect(c.satisfied, p.islands.length);
      expect(
        c.progressText,
        '${p.islands.length} of ${p.islands.length} islets done',
      );
    });

    test(
      'hint: wrong bridges go first, then a spotlight, then a free build',
      () {
        final p = bridgesPuzzle();
        final c = BridgesController(p);

        // A bridge that is not in the answer.
        final right = {for (final l in p.solution) (l.a, l.b)};
        final stray = c.pairs.firstWhere((x) => !right.contains(x));
        c.cycle(stray.$1, stray.$2);
        final first = c.hint()!;
        expect(first.text, contains("didn't belong"));
        expect(c.links, isEmpty);
        expect(c.hintPending, isFalse);

        final second = c.hint()!;
        expect(second.actionLabel, 'Show me');
        expect(c.hintPending, isTrue);
        expect(c.spotlightIsland, isNotNull);

        final third = c.hint()!;
        expect(third.free, isTrue, reason: 'showing the bridge costs nothing');
        expect(c.hintPending, isFalse);
        expect(c.links, hasLength(1));
        expect(c.hintLink, isNotNull);
        final l = c.links.single;
        expect(
          p.solution.any((s) => s.a == l.a && s.b == l.b && s.count == l.count),
          isTrue,
          reason: 'the hint only ever builds part of the answer',
        );
      },
    );

    test('reset clears the board and can be undone', () {
      final p = bridgesPuzzle();
      final c = BridgesController(p);
      c.cycle(c.pairs.first.$1, c.pairs.first.$2);
      c.reset();
      expect(c.links, isEmpty);
      c.undo();
      expect(c.links, isNotEmpty);
    });
  });

  group('Sleuth play screen', () {
    testWidgets('tap a word, press Guess: tiles fill and the word is used up', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
      final p = sleuthPuzzle();
      final board = sleuthOf(tester);
      final w = wrongWords(p).first;

      expect(find.text('Theme: ${p.theme}'), findsOneWidget);
      await tester.tap(find.text(p.words[w]));
      await settle(tester, frames: 3);
      expect(board.picked, w);
      await capture(tester, 'sleuth_a_picked');

      await tester.tap(find.text('Guess'));
      await settle(tester, frames: 8);
      expect(board.history, hasLength(1));
      expect(board.history.single.word, w);
      expect(board.guessCount, 1);
      await capture(tester, 'sleuth_b_first_guess');
      await closeApp(tester, c);
    });

    testWidgets('Guess does nothing until a word is picked', (tester) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
      await tester.tap(find.text('Guess'));
      await settle(tester, frames: 3);
      expect(sleuthOf(tester).history, isEmpty);
      await closeApp(tester, c);
    });

    testWidgets('long-press crosses a word out', (tester) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
      final p = sleuthPuzzle();
      final w = wrongWords(p).last;
      await tester.longPress(find.text(p.words[w]));
      await settle(tester, frames: 3);
      expect(sleuthOf(tester).struck, contains(w));
      await tester.longPress(find.text(p.words[w]));
      await settle(tester, frames: 3);
      expect(sleuthOf(tester).struck, isEmpty);
      await closeApp(tester, c);
    });

    testWidgets('Hint picks a word, spends one hint, never costs a life', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
      final save = c.read(saveProvider.notifier);
      final hints = save.economyNow.hints;
      final lives = save.economyNow.lives;
      await tester.tap(find.text('Hint'));
      await settle(tester, frames: 4);
      expect(sleuthOf(tester).picked, isNotNull);
      expect(find.textContaining('Try '), findsWidgets);
      expect(save.economyNow.hints, hints - 1);
      expect(save.economyNow.lives, lives);
      await capture(tester, 'sleuth_c_hint');
      await closeApp(tester, c);
    });

    testWidgets('the secret word solves the level and records the stars', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
      final p = sleuthPuzzle();
      await tester.tap(find.text(p.answer));
      await settle(tester, frames: 3);
      await tester.tap(find.text('Guess'));
      await settle(tester, frames: 18);
      expect(find.text('Level 18 solved!'), findsOneWidget);
      final rec = c.read(saveProvider).progress(GameId.sleuth).levels[18];
      expect(rec, isNotNull);
      expect(rec!.stars, greaterThanOrEqualTo(1));
      await closeApp(tester, c);
    });

    testWidgets(
      'every guess used: a life is lost, the dialog offers another go with a new secret',
      (tester) async {
        final c = await pumpApp(tester, route: Routes.play(GameId.sleuth, 18));
        final p = sleuthPuzzle();
        final save = c.read(saveProvider.notifier);
        final lives = save.economyNow.lives;
        final board = sleuthOf(tester);
        for (final w in wrongWords(p).take(p.tries)) {
          await tester.tap(find.text(p.words[w]));
          await settle(tester, frames: 2);
          await tester.tap(find.text('Guess'));
          await settle(tester, frames: 8);
        }
        expect(find.text('Out of guesses'), findsOneWidget);
        expect(
          find.textContaining('The word was ${p.answer}.'),
          findsOneWidget,
        );
        expect(save.economyNow.lives, lives - 1);
        await capture(tester, 'sleuth_d_out_of_guesses');

        await tester.tap(find.text('Try again'));
        await settle(tester, frames: 6);
        expect(find.text('Out of guesses'), findsNothing);
        expect(board.history, isEmpty);
        expect(board.puzzle.secret, isNot(p.secret));
        expect(
          save.economyNow.lives,
          lives - 1,
          reason: 'only one life is lost',
        );
        await closeApp(tester, c);
      },
    );

    testWidgets('replaying a solved level never costs a life', (tester) async {
      final s = sampleSave();
      final solved = s.copyWith(
        games: {
          ...s.games,
          GameId.sleuth: const GameProgress(
            levels: {
              18: LevelRecord(
                stars: 3,
                bestSeconds: 40,
                noHint: true,
                solvedAt: 1,
              ),
            },
          ),
        },
      );
      final c = await pumpApp(
        tester,
        route: Routes.play(GameId.sleuth, 18),
        save: solved,
      );
      final p = sleuthPuzzle();
      final save = c.read(saveProvider.notifier);
      final lives = save.economyNow.lives;
      for (final w in wrongWords(p).take(p.tries)) {
        await tester.tap(find.text(p.words[w]));
        await settle(tester, frames: 2);
        await tester.tap(find.text('Guess'));
        await settle(tester, frames: 8);
      }
      expect(find.text('Out of guesses'), findsOneWidget);
      expect(save.economyNow.lives, lives);
      await closeApp(tester, c);
    });
  });

  group('Bridges play screen', () {
    testWidgets('tapping a gap builds, double-builds and removes a bridge', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.bridges, 18));
      final p = bridgesPuzzle();
      final board = bridgesOf(tester);
      final l = p.solution.first;

      await tapGap(tester, p, l.a, l.b);
      expect(board.bridgesBetween(l.a, l.b), 1);
      await tapGap(tester, p, l.a, l.b);
      expect(board.bridgesBetween(l.a, l.b), 2);
      await tapGap(tester, p, l.a, l.b);
      expect(board.bridgesBetween(l.a, l.b), 0);
      await closeApp(tester, c);
    });

    testWidgets('dragging from one islet to another builds the bridge', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.bridges, 18));
      final p = bridgesPuzzle();
      final board = bridgesOf(tester);
      final l = p.solution.first;
      final (box, cell) = bridgesArea(tester, p);
      final g = await tester.startGesture(isletCentre(box, cell, p, l.a));
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveTo(
        (isletCentre(box, cell, p, l.a) + isletCentre(box, cell, p, l.b)) / 2,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveTo(isletCentre(box, cell, p, l.b));
      await tester.pump(const Duration(milliseconds: 20));
      await capture(tester, 'bridges_a_dragging');
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(board.bridgesBetween(l.a, l.b), 1);
      await closeApp(tester, c);
    });

    testWidgets('a crossing bridge is refused with a message you can dismiss', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        route: Routes.play(GameId.bridges, crossingLevel),
      );
      final p = bridgesPuzzle(crossingLevel);
      final board = bridgesOf(tester);
      final (first, second) = crossingPairs(p);
      await tapGap(
        tester,
        p,
        first.$1,
        first.$2,
        along: clearOfCrossing(p, first, second),
      );
      expect(board.bridgesBetween(first.$1, first.$2), 1);
      await tapGap(
        tester,
        p,
        second.$1,
        second.$2,
        along: clearOfCrossing(p, second, first),
      );
      await settle(tester, frames: 3);
      expect(find.text("A bridge can't cross another one."), findsOneWidget);
      expect(board.bridgesBetween(second.$1, second.$2), 0);
      await capture(tester, 'bridges_b_blocked');
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, frames: 4);
      expect(find.text("A bridge can't cross another one."), findsNothing);
      await closeApp(tester, c);
    });

    testWidgets('Hint → spotlight and reason → Show me builds it, free', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.bridges, 18));
      final save = c.read(saveProvider.notifier);
      final before = save.economyNow.hints;
      await tester.tap(find.text('Hint'));
      await settle(tester, frames: 4);
      expect(find.textContaining('Look at the glowing islet'), findsOneWidget);
      expect(find.text('Show me'), findsOneWidget);
      expect(save.economyNow.hints, before - 1);
      await capture(tester, 'bridges_c_hint_spotlight');

      await tester.tap(find.text('Show me'));
      await settle(tester, frames: 4);
      expect(find.text('Show me'), findsNothing);
      expect(find.textContaining('Built '), findsOneWidget);
      expect(save.economyNow.hints, before - 1, reason: 'showing is free');
      expect(bridgesOf(tester).links, hasLength(1));
      await capture(tester, 'bridges_d_hint_placed');
      await closeApp(tester, c);
    });

    testWidgets('building the whole answer by tapping solves the level', (
      tester,
    ) async {
      final c = await pumpApp(tester, route: Routes.play(GameId.bridges, 18));
      final p = bridgesPuzzle();
      for (final l in p.solution.take(p.solution.length - 1)) {
        for (var k = 0; k < l.count; k++) {
          await tapGap(tester, p, l.a, l.b);
        }
      }
      await capture(tester, 'bridges_e_nearly');
      final last = p.solution.last;
      for (var k = 0; k < last.count; k++) {
        await tapGap(tester, p, last.a, last.b);
      }
      await settle(tester, frames: 18);
      expect(find.text('Level 18 solved!'), findsOneWidget);
      expect(
        c.read(saveProvider).progress(GameId.bridges).levels[18],
        isNotNull,
      );
      await closeApp(tester, c);
    });

    testWidgets('screen reader: every possible bridge is a labelled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await pumpApp(tester, route: Routes.play(GameId.bridges, 18));
      final p = bridgesPuzzle();
      final l = p.solution.first;
      final label = RegExp(
        'Bridge between the ${p.islands[l.a].need} at row ${p.islands[l.a].row + 1}, '
        'column ${p.islands[l.a].col + 1} and .*: none built',
      );
      final nodes = semanticsLabelled(tester, label);
      expect(nodes, isNotEmpty);
      expect(
        semanticsLabelled(tester, RegExp('^Bridge between')),
        hasLength(p.graph.pairs.length),
        reason: 'one button per possible bridge',
      );
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        nodes.first.id,
        SemanticsAction.tap,
      );
      await settle(tester, frames: 3);
      expect(bridgesOf(tester).links, hasLength(1));
      handle.dispose();
      await closeApp(tester, c);
    });
  });

  // The biggest boards of each game on the smallest phone with large text: nothing
  // overflows, and the screenshot shows how it scrolls.
  for (final (game, level) in [
    (GameId.sleuth, 38),
    (GameId.sleuth, 60),
    (GameId.bridges, 46),
    (GameId.bridges, 60),
  ]) {
    testWidgets(
      '${game.title} level $level on a 360×640 phone at 1.3× text: nothing overflows',
      (tester) async {
        final c = await pumpApp(tester, route: Routes.play(game, level));
        tester.view.physicalSize = const Size(360 * 3, 640 * 3);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await settle(tester, frames: 6);
        expect(tester.takeException(), isNull);
        await capture(tester, 'small_${game.key}_$level');
        await closeApp(tester, c);
      },
    );
  }

  for (final night in [false, true]) {
    for (final game in [GameId.sleuth, GameId.bridges]) {
      testWidgets(
        '${game.title} board in ${night ? 'night' : 'day'} mode (screenshot)',
        (tester) async {
          final c = await pumpApp(
            tester,
            route: Routes.play(game, 18),
            save: sampleSave(
              theme: night ? ThemeChoice.night : ThemeChoice.day,
            ),
          );
          if (game == GameId.sleuth) {
            final p = sleuthPuzzle();
            final board = sleuthOf(tester);
            for (final w in wrongWords(p).take(2)) {
              board.pick(w);
              board.submit();
            }
            board.toggleStrike(wrongWords(p).last);
          } else {
            final p = bridgesPuzzle();
            final board = bridgesOf(tester);
            for (final l in p.solution.take(p.solution.length ~/ 2)) {
              for (var k = 0; k < l.count; k++) {
                board.cycle(l.a, l.b);
              }
            }
          }
          await settle(tester, frames: 10);
          await capture(tester, '${night ? 'night' : 'day'}_play_${game.key}');
          await closeApp(tester, c);
        },
      );
    }
  }
}
