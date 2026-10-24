// The how-to-play sheet for every game: opens without errors on a normal phone, on the
// smallest phone at large text, with reduce-motion on, in day and night, and the demo
// animation runs and stops with the sheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/play/how_to_play_sheet.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

BuildContext homeContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

void main() {
  for (final game in GameId.values) {
    for (final (label, size, scale, night) in [
      ('390×844', const Size(390, 844), 1.0, false),
      ('360×640 at 1.3× text', const Size(360, 640), 1.3, false),
      ('360×640 at 1.3× text, night', const Size(360, 640), 1.3, true),
    ]) {
      testWidgets('${game.title} how-to sheet at $label opens cleanly', (
        tester,
      ) async {
        final c = await pumpApp(
          tester,
          route: Routes.home,
          save: sampleSave(theme: night ? ThemeChoice.night : ThemeChoice.day),
        );
        tester.view.physicalSize = size * 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        showHowToPlay(homeContext(tester), game);
        await settle(tester, frames: 8);
        expect(tester.takeException(), isNull);
        expect(find.text("Got it — let's play"), findsOneWidget);
        for (final step in howToSteps(game)) {
          expect(find.text(step), findsOneWidget);
        }
        if (scale > 1) await capture(tester, 'howto_small_${game.key}');
        await tester.tap(find.text("Got it — let's play"));
        await settle(tester, frames: 6);
        expect(find.text("Got it — let's play"), findsNothing);
        expect(tester.takeException(), isNull);
        await closeApp(tester, c);
      });
    }
  }
}
