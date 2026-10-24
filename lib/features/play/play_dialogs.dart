// Dialogs and sheets used while playing: time's up, pause, out of hints,
// confirm hint, leave level.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import 'play_hud.dart' show clockText;
import '../../core/constants/plural.dart';

enum TimeUpChoice { keepGoing, restart, leave }

Future<TimeUpChoice> showTimeUp(BuildContext context, {required int livesLeft, required int clockSeconds, required IslandStyle style}) async {
  final r = await showDialog<TimeUpChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: context.mi.scrim,
    builder: (ctx) {
      final c = ctx.mi;
      final instant = MediaQuery.disableAnimationsOf(ctx);
      Widget alarm = Icon(Icons.alarm_rounded, size: 88, color: style.color);
      if (!instant) alarm = alarm.animate(onPlay: (a) => a.repeat()).shake(hz: 5, duration: 900.ms, rotation: .08).then(delay: 700.ms);
      return PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              alarm,
              const SizedBox(height: 8),
              Text("Time's up!", style: MiText.display.copyWith(color: c.ink)),
              const SizedBox(height: 10),
              Semantics(
                label: '${plural(livesLeft, 'life', 'lives')} left',
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: i < livesLeft
                          ? Icon(Icons.favorite_rounded, size: 36, color: c.heart)
                          : (i == livesLeft
                              ? (instant
                                  ? Icon(Icons.heart_broken_rounded, size: 36, color: c.heart.withValues(alpha: .4))
                                  : Icon(Icons.heart_broken_rounded, size: 36, color: c.heart).animate().fade(begin: 1, end: .35, delay: 300.ms, duration: 600.ms).scaleXY(end: .85))
                              : Icon(Icons.favorite_border_rounded, size: 36, color: c.inkSoft.withValues(alpha: .5))),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                'You lost a life, but your board is saved. Here\'s a fresh ${clockText(clockSeconds)} on the clock.',
                textAlign: TextAlign.center,
                style: MiText.body.copyWith(color: c.inkSoft, fontSize: 17),
              ),
              const SizedBox(height: 18),
              MiButton(label: 'Keep going', color: style.color, ledge: style.ledge, onColor: style.onColor, onTap: () => Navigator.pop(ctx, TimeUpChoice.keepGoing)),
              MiTextButton(label: 'Start the level over', color: style.ink, onTap: () => Navigator.pop(ctx, TimeUpChoice.restart)),
              MiTextButton(label: 'Leave level', color: c.inkSoft, onTap: () => Navigator.pop(ctx, TimeUpChoice.leave)),
            ]),
          ),
        ),
      );
    },
  );
  return r ?? TimeUpChoice.keepGoing;
}

enum PauseChoice { resume, restart, howTo, leave }

Future<PauseChoice> showPauseSheet(BuildContext context, IslandStyle style) async {
  final r = await showMiSheet<PauseChoice>(
    context,
    builder: (ctx) {
      final c = ctx.mi;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Paused', textAlign: TextAlign.center, style: MiText.display.copyWith(color: c.ink)),
        const SizedBox(height: 4),
        Text('The clock is stopped.', textAlign: TextAlign.center, style: MiText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: 16),
        MiButton(label: 'Resume', icon: Icons.play_arrow_rounded, color: style.color, ledge: style.ledge, onColor: style.onColor, onTap: () => Navigator.pop(ctx, PauseChoice.resume)),
        const SizedBox(height: 10),
        MiGhostButton(label: 'Restart level', icon: Icons.refresh_rounded, onTap: () => Navigator.pop(ctx, PauseChoice.restart)),
        const SizedBox(height: 10),
        MiGhostButton(label: 'How to play', icon: Icons.help_outline_rounded, onTap: () => Navigator.pop(ctx, PauseChoice.howTo)),
        MiTextButton(label: 'Leave level', color: c.danger, onTap: () => Navigator.pop(ctx, PauseChoice.leave)),
      ]);
    },
  );
  return r ?? PauseChoice.resume;
}

/// "Out of hints" — offers a rewarded ad when one is ready.
Future<bool> showOutOfHints(BuildContext context, {required bool adReady}) async {
  final r = await showMiSheet<bool>(
    context,
    builder: (ctx) {
      final c = ctx.mi;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.lightbulb_outline_rounded, size: 56, color: Color(0xFFE0A100)),
        const SizedBox(height: 6),
        Text('No hints left', textAlign: TextAlign.center, style: MiText.title.copyWith(color: c.ink)),
        const SizedBox(height: 6),
        Text('Three free hints come back every day. Achievements and tier chests give extra ones.', textAlign: TextAlign.center, style: MiText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: 16),
        if (adReady) MiButton.sun(label: 'Watch a short ad · +1 hint', icon: Icons.play_circle_rounded, onTap: () => Navigator.pop(ctx, true)),
        if (!adReady) Text('No ad is available right now — try again in a minute.', textAlign: TextAlign.center, style: MiText.small.copyWith(color: c.inkSoft)),
        MiTextButton(label: 'Keep thinking', onTap: () => Navigator.pop(ctx, false)),
      ]);
    },
  );
  return r ?? false;
}

Future<bool> confirmHint(BuildContext context, int left) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Use a hint?', style: MiText.title),
      content: Text('You have $left. Using one takes away this level\'s no-hint star.', style: MiText.body.copyWith(color: ctx.mi.inkSoft)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use hint')),
      ],
    ),
  );
  return r ?? false;
}

Future<bool> confirmLeave(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Leave this level?', style: MiText.title),
      content: Text("Your board won't be saved. You won't lose a life.", style: MiText.body.copyWith(color: ctx.mi.inkSoft)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
      ],
    ),
  );
  return r ?? false;
}
