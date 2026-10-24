// The shared confirm dialog: answers, the Android back button, the Exit prompt,
// and screenshots of every dialog (day, night, large text on a narrow phone).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/router/app_router.dart';
import 'package:focus_and_play_mindgame/core/widgets/mi_dialog.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/features/play/play_dialogs.dart';

import '../helpers/app_harness.dart';
import '../helpers/screen_capture.dart';

BuildContext homeContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

void main() {
  testWidgets('Exit prompt: the back button on Home asks, Stay keeps the app', (
    tester,
  ) async {
    final c = await pumpApp(tester, route: Routes.home);
    await tester.binding.handlePopRoute();
    await settle(tester, frames: 4);
    expect(find.text('Leaving already?'), findsOneWidget);
    await capture(tester, 'dialog_a_exit');

    await tester.tap(find.text('Stay and play'));
    await settle(tester, frames: 4);
    expect(find.text('Leaving already?'), findsNothing);
    expect(find.text('Your islands'), findsOneWidget);
    await closeApp(tester, c);
  });

  testWidgets(
    'answers: the big button and the text button map to true / false; back and tap-outside are false',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.home);
      Future<bool?> ask({bool primaryConfirm = true}) async {
        bool? result;
        showMiConfirm(
          homeContext(tester),
          title: 'Sure?',
          message: 'Really?',
          confirmLabel: 'Yes',
          cancelLabel: 'No',
          confirmIsPrimary: primaryConfirm,
        ).then((v) => result = v);
        await settle(tester, frames: 4);
        return result;
      }

      // Risky confirm: "No" is the big button.
      bool? got;
      showMiConfirm(
        homeContext(tester),
        title: 'Leave?',
        message: 'm',
        confirmLabel: 'Leave',
        cancelLabel: 'Stay',
        confirmIsPrimary: false,
      ).then((v) => got = v);
      await settle(tester, frames: 4);
      await tester.tap(find.text('Stay'));
      await settle(tester, frames: 4);
      expect(got, isFalse);

      showMiConfirm(
        homeContext(tester),
        title: 'Leave?',
        message: 'm',
        confirmLabel: 'Leave',
        cancelLabel: 'Stay',
        confirmIsPrimary: false,
      ).then((v) => got = v);
      await settle(tester, frames: 4);
      await tester.tap(find.text('Leave'));
      await settle(tester, frames: 4);
      expect(got, isTrue);

      // Android back button dismisses = false.
      got = null;
      await ask();
      showMiConfirm(
        homeContext(tester),
        title: 'Back?',
        message: 'm',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      ).then((v) => got = v);
      await settle(tester, frames: 4);
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 4);
      expect(got, isFalse);

      // Tap outside dismisses = false.
      got = null;
      showMiConfirm(
        homeContext(tester),
        title: 'Out?',
        message: 'm',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      ).then((v) => got = v);
      await settle(tester, frames: 4);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester, frames: 4);
      expect(got, isFalse);
      await closeApp(tester, c);
    },
  );

  for (final night in [false, true]) {
    testWidgets('every dialog, ${night ? 'night' : 'day'}', (tester) async {
      final c = await pumpApp(
        tester,
        route: Routes.home,
        save: sampleSave(theme: night ? ThemeChoice.night : ThemeChoice.day),
      );
      final tag = night ? 'night' : 'day';
      Future<void> shot(String name, Future<bool> Function() open) async {
        open();
        await settle(tester, frames: 5);
        await capture(tester, 'dialog_${name}_$tag');
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 3);
      }

      await shot('leave_level', () => confirmLeave(homeContext(tester)));
      await shot('hint', () => confirmHint(homeContext(tester), 3));
      await shot(
        'reset',
        () => showMiConfirm(
          homeContext(tester),
          icon: Icons.restart_alt_rounded,
          tone: MiDialogTone.danger,
          title: 'Reset all progress?',
          message: 'Levels, stars, insights and achievements on this phone are cleared. Your name and settings stay. A backup is saved first, just in case.',
          confirmLabel: 'Reset',
          cancelLabel: 'Keep my progress',
          confirmIsPrimary: false,
        ),
      );
      if (night) {
        await tester.binding.handlePopRoute();
        await settle(tester, frames: 4);
        expect(find.text('Leaving already?'), findsOneWidget);
        await capture(tester, 'dialog_exit_night');
      }
      await closeApp(tester, c);
    });
  }

  testWidgets(
    'narrow phone + large text: nothing overflows and both buttons stay reachable',
    (tester) async {
      final c = await pumpApp(tester, route: Routes.home);
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      showMiConfirm(
        homeContext(tester),
        icon: Icons.restart_alt_rounded,
        tone: MiDialogTone.danger,
        title: 'Reset all progress?',
        message: 'Levels, stars, insights and achievements on this phone are cleared. Your name and settings stay. A backup is saved first, just in case.',
        confirmLabel: 'Reset',
        cancelLabel: 'Keep my progress',
        confirmIsPrimary: false,
      );
      await settle(tester, frames: 5);
      expect(tester.takeException(), isNull);
      expect(find.text('Keep my progress'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      await capture(tester, 'dialog_narrow_large_text');
      await tester.binding.handlePopRoute();
      await settle(tester, frames: 3);
      await closeApp(tester, c);
    },
  );
}
