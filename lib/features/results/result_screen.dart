// The celebration after a solve: stars pop in one by one, confetti falls, and
// the stats, achievements and chest rewards follow. No ads here.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_info.dart';
import '../../core/feedback/feedback.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/achievements.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import '../play/play_hud.dart' show clockText;
import 'achievement_dialog.dart';
import 'result_flow.dart';
import '../../core/constants/plural.dart';

const _navy = Color(0xFF13213C);

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.outcome});
  final LevelOutcome outcome;
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  LevelOutcome get o => widget.outcome;

  @override
  void initState() {
    super.initState();
    final fb = ref.read(feedbackProvider);
    for (var i = 0; i < o.stars; i++) {
      Future<void>.delayed(Duration(milliseconds: 250 + i * 300), () {
        if (mounted) fb.play(Sfx.star, volume: .6);
      });
    }
    if (o.chestHints > 0) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () => fb.play(Sfx.chest));
    }
    if (o.newAchievements.isNotEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 1700), () async {
        for (final a in o.newAchievements) {
          if (!mounted) return;
          await showAchievement(context, a);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _rays.stop() : _rays.repeat();
  }

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  String get _cheer {
    final name = ref.read(saveProvider).profile.name;
    final who = name.isEmpty ? '' : ', $name';
    if (o.relaxed) return 'Nicely done$who.';
    return switch (o.stars) {
      3 => 'Brilliant$who — three stars.',
      2 => 'Great work$who — two stars.',
      _ => 'Solved! Try again for more stars.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final st = IslandStyle.of(o.spec.game, MiColors.night);
    final instant = MediaQuery.disableAnimationsOf(context);
    final last = o.spec.isDaily || o.spec.level >= Levels.perIsland;
    final title = o.spec.isDaily
        ? 'Daily puzzle solved!'
        : 'Level ${o.spec.level} solved!';
    Widget pop(Widget w, int i) => instant
        ? w
        : w.animate().scale(
            delay: (250 + i * 300).ms,
            duration: 550.ms,
            curve: Curves.elasticOut,
            begin: Offset.zero,
          );
    Widget rise(Widget w, int i) => instant
        ? w
        : w
              .animate()
              .fadeIn(delay: (900 + i * 120).ms, duration: 400.ms)
              .slideY(begin: .2, curve: Curves.easeOut);
    final vsPar = o.seconds - o.spec.parSeconds;

    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _Rays(_rays, st.color))),
          const Positioned.fill(child: Confetti(count: 46)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 130,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                pop(
                                  StarShape(
                                    filled: o.stars >= 1,
                                    size: 72,
                                    stroke: const Color(0xFFFFE7A3),
                                  ),
                                  0,
                                ),
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 22),
                                  child: pop(
                                    StarShape(
                                      filled: o.stars >= 2,
                                      size: 100,
                                      stroke: const Color(0xFFFFE7A3),
                                    ),
                                    1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                pop(
                                  StarShape(
                                    filled: o.stars >= 3,
                                    size: 72,
                                    stroke: const Color(0xFFFFE7A3),
                                  ),
                                  2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          rise(
                            Text(
                              '${o.spec.game.island.toUpperCase()} · ${o.spec.game.title.toUpperCase()}',
                              style: MiText.overline.copyWith(color: st.ink),
                            ),
                            0,
                          ),
                          const SizedBox(height: 4),
                          rise(
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: MiText.hero.copyWith(color: Colors.white),
                            ),
                            1,
                          ),
                          const SizedBox(height: 4),
                          rise(
                            Text(
                              _cheer,
                              textAlign: TextAlign.center,
                              style: MiText.body.copyWith(
                                color: const Color(0xFFC9D6EA),
                                fontSize: 17,
                              ),
                            ),
                            2,
                          ),
                          const SizedBox(height: 14),
                          rise(
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                _Chip(ok: true, text: 'Solved'),
                                if (!o.relaxed)
                                  _Chip(
                                    ok: o.seconds <= o.spec.parSeconds,
                                    text:
                                        'Under ${clockText(o.spec.parSeconds)}',
                                  ),
                                if (!o.relaxed)
                                  _Chip(ok: o.hints == 0, text: 'No hints'),
                                if (o.relaxed)
                                  const _Chip(ok: true, text: 'Relaxed mode'),
                              ],
                            ),
                            3,
                          ),
                          const SizedBox(height: 14),
                          rise(
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C2C49),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  _Stat(
                                    value: clockText(o.seconds),
                                    label: 'Time',
                                  ),
                                  _Stat(
                                    value: o.newBest
                                        ? 'New best'
                                        : (vsPar <= 0
                                              ? '−${clockText(-vsPar)}'
                                              : '+${clockText(vsPar)}'),
                                    label: o.newBest
                                        ? 'was ${clockText(o.previousBest!)}'
                                        : (vsPar <= 0
                                              ? 'under par'
                                              : 'over par'),
                                    accent: o.newBest || vsPar <= 0,
                                    divided: true,
                                  ),
                                  _Stat(value: '+${o.xp}', label: 'XP'),
                                ],
                              ),
                            ),
                            4,
                          ),
                          const SizedBox(height: 10),
                          if (o.chestHints > 0)
                            rise(
                              _Reward(
                                icon: Icons.inventory_2_rounded,
                                title: 'Tier chest opened!',
                                sub: '+${plural(o.chestHints, 'hint')}',
                              ),
                              5,
                            ),
                          for (final (i, a) in o.newAchievements.indexed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: rise(
                                _AchievementChip(
                                  def: a,
                                  onTap: () => showAchievement(context, a),
                                ),
                                6 + i,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  rise(
                    Column(
                      children: [
                        MiButton(
                          label:
                              o.tierCleared != null &&
                                  o.tierCleared != Tier.expert
                              ? 'Open the next tier'
                              : (last ? 'Back home' : 'Next level'),
                          trailingIcon: Icons.arrow_forward_rounded,
                          color: st.color,
                          ledge: st.ledge,
                          onColor: st.onColor,
                          height: 60,
                          onTap: () {
                            if (o.tierCleared != null &&
                                o.tierCleared != Tier.expert) {
                              context.pushReplacement(Routes.tier, extra: o);
                            } else {
                              goToNextLevel(context, ref, o.spec);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: MiGhostButton(
                                label: o.spec.isDaily
                                    ? 'Home'
                                    : 'Back to island',
                                color: Colors.white,
                                onTap: () => o.spec.isDaily
                                    ? context.go(Routes.home)
                                    : context.pop(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MiGhostButton(
                                label: 'Share',
                                icon: Icons.ios_share_rounded,
                                color: Colors.white,
                                onTap: () => SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'I solved ${o.spec.isDaily ? "today's ${o.spec.game.title}" : '${o.spec.game.title} level ${o.spec.level}'} in ${clockText(o.seconds)} '
                                        'with ${o.stars} ${o.stars == 1 ? 'star' : 'stars'} on ${AppInfo.name}.',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ok, required this.text});
  final bool ok;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF24324D),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_rounded : Icons.close_rounded,
          size: 16,
          color: ok ? const Color(0xFF7EE0C8) : const Color(0xFF8C9BB3),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: MiText.caption.copyWith(
            color: ok ? Colors.white : const Color(0xFFB5C3D9),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.accent = false,
    this.divided = false,
  });
  final String value, label;
  final bool accent, divided;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: divided
          ? const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0xFF2E3E5C), width: 1.5),
              ),
            )
          : null,
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: MiText.title.copyWith(
                fontSize: 23,
                color: accent ? const Color(0xFFFFC233) : Colors.white,
              ),
            ),
          ),
          Text(
            label,
            style: MiText.caption.copyWith(color: const Color(0xFFB5C3D9)),
          ),
        ],
      ),
    ),
  );
}

class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1CC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, size: 34, color: const Color(0xFFB7791F)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: MiText.headline.copyWith(color: _navy)),
        ),
        Text(
          sub,
          style: MiText.headline.copyWith(color: const Color(0xFF6B4A00)),
        ),
      ],
    ),
  );
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.def, required this.onTap});
  final AchievementDef def;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MiPressable(
    onTap: onTap,
    color: const Color(0xFFFFF1CC),
    radius: 20,
    semanticLabel: 'Achievement unlocked: ${def.title}',
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        HexBadge(kind: def.kind, unlocked: true, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACHIEVEMENT UNLOCKED',
                style: MiText.overline.copyWith(
                  color: const Color(0xFF6B4A00),
                  fontSize: 11,
                ),
              ),
              Text(def.title, style: MiText.headline.copyWith(color: _navy)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: _navy),
      ],
    ),
  );
}

class _Rays extends CustomPainter {
  _Rays(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .2);
    final p = Paint()..color = color.withValues(alpha: .18);
    final r = size.longestSide;
    for (var i = 0; i < 12; i++) {
      final a = t.value * 2 * pi + i * pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - .09) * r, c.dy + sin(a - .09) * r)
        ..lineTo(c.dx + cos(a + .09) * r, c.dy + sin(a + .09) * r)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => false;
}
