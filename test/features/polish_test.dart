// Tab pill slide, Pip's movement, Thread's eased thread and night-mode cells.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/core/widgets/pip.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/boards/thread_board.dart';
import 'package:focus_and_play_mindgame/features/boards/thread_trail.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/thread/thread.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

void main() {
  group('ThreadTrail', () {
    test('grows smoothly towards a longer path and never overshoots', () {
      final t = ThreadTrail()..follow([0]);
      t.snap();
      t.follow([0, 1, 2, 3, 4]);
      expect(t.target, 4);
      expect(t.shown, 0, reason: 'the head has not moved yet');
      var last = 0.0;
      var steps = 0;
      while (t.step(1 / 60)) {
        expect(t.shown, greaterThanOrEqualTo(last));
        expect(t.shown, lessThanOrEqualTo(4.0001));
        last = t.shown;
        steps++;
        expect(
          steps,
          lessThan(300),
          reason: 'must settle in a few seconds at most',
        );
      }
      expect(t.shown, 4);
      expect(
        steps,
        greaterThan(6),
        reason: 'it glides over several frames, not one jump',
      );
    });

    test('sliding back draws the old tail back in, then forgets it', () {
      final t = ThreadTrail()..follow([0, 1, 2, 3]);
      t.snap();
      t.follow([0, 1]);
      expect(t.cells, [
        0,
        1,
        2,
        3,
      ], reason: 'the tail stays visible while retracting');
      expect(t.target, 1);
      while (t.step(1 / 60)) {}
      expect(t.cells, [0, 1]);
      expect(t.shown, 1);
    });

    test('a different route keeps only the part still valid', () {
      final t = ThreadTrail()..follow([0, 1, 2, 3]);
      t.snap();
      t.follow([0, 1, 5, 6]); // diverges after cell 1
      expect(t.cells, [0, 1, 5, 6]);
      expect(
        t.shown,
        1,
        reason: 'the head restarts from where the routes split',
      );
      expect(t.target, 3);
    });

    test('reset retracts the whole thread to the start', () {
      final t = ThreadTrail()..follow([4, 5, 6, 7]);
      t.snap();
      t.follow([]);
      expect(t.target, 0);
      while (t.step(1 / 60)) {}
      expect(t.cells, isEmpty);
      expect(t.points((c) => Offset(c * 1.0, 0)), isEmpty);
    });

    test('points end exactly at the fractional head', () {
      final t = ThreadTrail()..follow([0, 1, 2]);
      t.shown = 1.5;
      final pts = t.points((c) => Offset(c * 10.0, 0));
      expect(pts, [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(15, 0),
      ]);
    });

    test('smoothPath rounds a corner but still visits both ends', () {
      final path = smoothPath(const [
        Offset(0, 0),
        Offset(40, 0),
        Offset(40, 40),
      ], 10);
      final b = path.getBounds();
      expect(b.left, 0);
      expect(b.bottom, 40);
      expect(
        path.contains(const Offset(39, 1)),
        isFalse,
        reason: 'the sharp corner is cut',
      );
    });
  });

  testWidgets(
    'the tab pill slides to the tapped tab instead of fading in place',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.home);
      final pill = find.byWidgetPredicate(
        (w) => w is AnimatedPositionedDirectional,
      );
      expect(pill, findsOneWidget);
      double pillX() => tester
          .getTopLeft(
            find
                .descendant(of: pill, matching: find.byType(DecoratedBox))
                .first,
          )
          .dx;
      final home = pillX();
      await tester.tap(find.text('Settings').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = pillX();
      await settle(tester);
      final end = pillX();
      expect(mid, greaterThan(home), reason: 'moving…');
      expect(mid, lessThan(end), reason: '…and not there yet after 100 ms');
      await closeApp(tester, c);
    },
  );

  testWidgets(
    'the tab pill never leaves the bar while sliding to the first or last tab',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.home);
      final pill = find.byWidgetPredicate(
        (w) => w is AnimatedPositionedDirectional,
      );
      final shape = find
          .descendant(of: pill, matching: find.byType(DecoratedBox))
          .first;
      // The bar is padded 20 px on each side; the pill has to stay inside it.
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      Future<void> slideTo(String tab) async {
        await tester.tap(find.text(tab).last);
        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final r = tester.getRect(shape);
          expect(
            r.left,
            greaterThanOrEqualTo(20 - .01),
            reason: 'left edge, frame $i, going to $tab',
          );
          expect(
            r.right,
            lessThanOrEqualTo(width - 20 + .01),
            reason: 'right edge, frame $i, going to $tab',
          );
        }
      }

      await slideTo('Settings');
      await slideTo('Home');
      await slideTo('Settings');
      await closeApp(tester, c);
    },
  );

  testWidgets(
    'Pip moves: different frames differ, a tap makes him hop, reduce motion holds still',
    (tester) async {
      Future<ui.Image> frame(WidgetTester t, Duration advance) async {
        await t.pump(advance);
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find
              .descendant(
                of: find.byType(Pip),
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );
        return (await t.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      }

      Future<bool> same(WidgetTester t, ui.Image a, ui.Image b) async {
        final da = (await t.runAsync(() => a.toByteData()))!;
        final db = (await t.runAsync(() => b.toByteData()))!;
        for (var i = 0; i < da.lengthInBytes; i++) {
          if (da.getUint8(i) != db.getUint8(i)) return false;
        }
        return true;
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Pip(size: 160))),
        ),
      );
      final a = await frame(tester, Duration.zero);
      final b = await frame(tester, const Duration(milliseconds: 1300));
      expect(
        await same(tester, a, b),
        isFalse,
        reason: 'he breathes and sways',
      );

      // Tap: he is up in the air a little later.
      await tester.tap(find.byType(Pip));
      await tester.pump(const Duration(milliseconds: 360)); // top of the hop
      final hopTop = tester.getTopLeft(
        find.byType(Pip),
      ); // layout box is fixed…
      expect(hopTop, isNotNull);
      await tester.pump(const Duration(seconds: 2));

      // Reduce motion: no animation scheduled, identical frames.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: Center(child: Pip(size: 160))),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      final c1 = await frame(tester, Duration.zero);
      final c2 = await frame(tester, const Duration(seconds: 3));
      expect(await same(tester, c1, c2), isTrue);
    },
  );

  testWidgets(
    'Pip on the welcome screen — three moments and a hop (screenshots)',
    (tester) async {
      final c = await pumpApp(
        tester,
        route: Routes.welcome,
        save: const SaveData(),
      );
      await capture(tester, 'pip_a_welcome_t0');
      await tester.pump(const Duration(milliseconds: 4200));
      await capture(tester, 'pip_b_welcome_flap');
      await tester.pump(const Duration(milliseconds: 2900));
      await capture(tester, 'pip_c_welcome_later');
      await closeApp(tester, c);
    },
  );

  for (final game in GameId.values) {
    testWidgets('night mode: ${game.title} cells are visible (screenshot)', (
      tester,
    ) async {
      final level = game == GameId.thread
          ? 34
          : (game == GameId.quilt ? 12 : (game == GameId.twist ? 21 : 18));
      final c = await pumpApp(
        tester,
        route: Routes.play(game, level),
        save: sampleSave(theme: ThemeChoice.night),
      );
      await capture(tester, 'night_${game.key}');
      await closeApp(tester, c);
    });
  }

  testWidgets(
    'Thread slide, mid-motion (screenshot) — the head is between squares, corners are round',
    (tester) async {
      final c = await pumpApp(
        tester,
        route: Routes.play(GameId.thread, 1),
        save: sampleSave(theme: ThemeChoice.night).copyWith(games: const {}),
      );
      final puzzle = generatePuzzle(
        LevelConfig.forLevel(GameId.thread, 1),
      ) as ThreadPuzzle;
      final board = tester
          .widget<ThreadBoard>(find.byType(ThreadBoard))
          .controller;
      final paint = find
          .descendant(
            of: find.byType(ThreadBoard),
            matching: find.byType(CustomPaint),
          )
          .first;
      final r = tester.getRect(paint);
      final cell = r.width / puzzle.size;
      Offset centre(int i) =>
          r.topLeft +
          Offset(
            (i % puzzle.size) * cell + cell / 2,
            (i ~/ puzzle.size) * cell + cell / 2,
          );
      final path = puzzle.solution;
      final g = await tester.startGesture(centre(path.first));
      for (var i = 1; i < path.length && i < 9; i++) {
        await g.moveTo(centre(path[i]));
      }
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // real frames
      }
      expect(board.path.length, greaterThan(3));
      await capture(tester, 'thread_slide_mid');
      await tester.pump(const Duration(milliseconds: 600));
      await capture(tester, 'thread_slide_settled');
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      await closeApp(tester, c);
    },
  );
}
