// Out of lives: kind, not punishing. Shows when the next heart comes back,
// offers a rewarded ad for one life, replaying solved levels (no lives needed)
// and a reminder when all lives are back.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/pinned_page.dart';
import '../../domain/level_config.dart';
import '../../domain/rules.dart';
import '../../domain/save_data.dart';
import '../../state/save_controller.dart';

class OutOfLivesScreen extends ConsumerStatefulWidget {
  const OutOfLivesScreen({super.key, this.spec});
  final LevelSpec? spec;
  @override
  ConsumerState<OutOfLivesScreen> createState() => _OutOfLivesScreenState();
}

class _OutOfLivesScreenState extends ConsumerState<OutOfLivesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _watching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _breathe.stop()
        : _breathe.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  Future<void> _watchAd() async {
    setState(() => _watching = true);
    final ok = await ref.read(adServiceProvider).showRewarded();
    if (!mounted) return;
    setState(() => _watching = false);
    if (ok) {
      ref.read(saveProvider.notifier).addLife();
      _playAgain();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No ad is available right now — try again in a minute.',
          ),
        ),
      );
    }
  }

  void _playAgain() {
    final s = widget.spec;
    if (s == null) {
      context.pop();
    } else {
      context.pushReplacement(
        s.isDaily ? Routes.daily() : Routes.play(s.game, s.level),
      );
    }
  }

  /// Back to the island map (replays of solved levels need no lives). The map is
  /// normally right underneath this screen; only push one when it isn't.
  void _toIsland() {
    final island = Routes.island(widget.spec!.game);
    final matches = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .matches;
    final below = matches.length >= 2
        ? matches[matches.length - 2].matchedLocation
        : null;
    if (below == island) {
      context.pop();
    } else {
      context.pushReplacement(island);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final e = ref.watch(economyProvider);
    final now = ref.read(clockProvider)();
    final next = EconomyRules.nextLifeIn(ref.read(saveProvider).economy, now);
    final full = EconomyRules.fullAt(ref.read(saveProvider).economy, now);
    final alert = ref.watch(settingsProvider.select((s) => s.livesAlert));
    final ads = ref.read(adServiceProvider);
    String mmss(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final frac = next == null
        ? 1.0
        : 1 - next.inSeconds / (Economy.refillMinutes * 60);

    final ground = c.isNight ? c.page : const Color(0xFFFFF3F5);
    return Scaffold(
      backgroundColor: ground,
      body: SafeArea(
        child: PinnedPage(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          headerPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          background: ground,
          header: Align(
            alignment: Alignment.centerLeft,
            child: MiIconButton(
              icon: Icons.close_rounded,
              label: 'Close',
              onTap: () => context.pop(),
            ),
          ),
          children: [
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _breathe,
                  builder: (context, _) => CustomPaint(
                    painter: _RingPainter(frac, c.heart, c.heartTint),
                    child: Center(
                      child: Transform.scale(
                        scale: 1 + _breathe.value * .06,
                        child: Icon(
                          e.lives > 0
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 64,
                          color: c.heart,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              e.lives > 0 ? 'A life is back!' : 'Out of lives',
              textAlign: TextAlign.center,
              style: MiText.display.copyWith(color: c.ink),
            ),
            const SizedBox(height: 6),
            Text(
              e.lives > 0
                  ? 'Jump back in whenever you like.'
                  : 'Take a breather — lives come back on their own.',
              textAlign: TextAlign.center,
              style: MiText.body.copyWith(color: c.inkSoft, fontSize: 17),
            ),
            const SizedBox(height: 18),
            MiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.lives >= Economy.maxLives
                              ? 'Lives are full'
                              : 'Next life in',
                          style: MiText.label.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (next != null)
                        Text(
                          mmss(next),
                          style: MiText.title.copyWith(color: c.danger),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < Economy.maxLives; i++)
                        Expanded(
                          child: Container(
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: c.heartTint,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: i < e.lives
                                  ? 1
                                  : (i == e.lives ? frac.clamp(0.0, 1.0) : 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c.heart,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (full != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'All three back in ${full.difference(now).inMinutes + 1} min · one every ${Economy.refillMinutes} min',
                      style: MiText.caption.copyWith(color: c.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (e.lives > 0 && widget.spec != null)
              MiButton(
                label: 'Play again',
                icon: Icons.play_arrow_rounded,
                onTap: _playAgain,
              )
            else
              MiButton.sun(
                label: _watching ? 'Loading…' : 'Watch a short ad · +1 life',
                icon: Icons.play_circle_rounded,
                onTap: _watching ? null : _watchAd,
              ),
            if (!ads.rewardedReady && e.lives == 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ads need an internet connection.',
                  textAlign: TextAlign.center,
                  style: MiText.caption.copyWith(color: c.inkSoft),
                ),
              ),
            const SizedBox(height: 12),
            if (widget.spec != null &&
                !widget.spec!.isDaily &&
                ref.watch(
                  saveProvider.select(
                    (s) => s.progress(widget.spec!.game).levels.isNotEmpty,
                  ),
                ))
              MiGhostButton(
                label: 'Replay a solved level',
                icon: Icons.replay_rounded,
                onTap: _toIsland,
              ),
            const SizedBox(height: 12),
            MiCard(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tell me when my lives are full',
                      style: MiText.label.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  MiSwitch(
                    value: alert,
                    label: 'Tell me when my lives are full',
                    onChanged: (v) async {
                      ref
                          .read(saveProvider.notifier)
                          .updateSettings((s) => s.copyWith(livesAlert: v));
                      final r = ref.read(reminderServiceProvider);
                      if (v) await r.requestPermission();
                      await r.sync(
                        ref.read(saveProvider),
                        ref.read(clockProvider)(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            MiTextButton(
              label: 'Back to Home',
              onTap: () => context.go(Routes.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac, this.color, this.track);
  final double frac;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(
      center: s.center(Offset.zero),
      radius: s.width / 2 - 8,
    );
    canvas.drawArc(
      r,
      0,
      2 * pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      r,
      -pi / 2,
      2 * pi * frac.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frac != frac;
}
