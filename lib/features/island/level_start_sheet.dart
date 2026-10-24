// Level sheet: tier, the three star goals, clock / lives / hints, best result,
// then Start (or the out-of-lives screen when no life is left).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../domain/game_id.dart';
import '../../domain/level_config.dart';
import '../../domain/rules.dart';
import '../../state/save_controller.dart';
import '../play/how_to_play_sheet.dart';
import '../play/puzzle_factory.dart';

String fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Opens the level sheet for [level] of [game].
Future<void> showLevelStart(
  BuildContext context,
  WidgetRef ref,
  GameId game,
  int level,
) {
  // Build the puzzle while the player reads the sheet, so Start opens it at once.
  prefetchPuzzle(LevelConfig.forLevel(game, level));
  return showMiSheet<void>(
    context,
    builder: (ctx) => _LevelStartSheet(game: game, level: level),
  );
}

/// Starts a level, or shows "out of lives" when the player has none (unless
/// Relaxed, or a replay of a solved level, which never costs a life).
void startLevel(BuildContext context, WidgetRef ref, LevelSpec spec) {
  ref.read(saveProvider.notifier).normaliseEconomy();
  final relaxed = ref.read(settingsProvider).relaxed;
  final lives = ref.read(saveProvider.notifier).economyNow.lives;
  if (!relaxed && lives <= 0 && !isReplay(ref.read(saveProvider), spec)) {
    context.push(Routes.outOfLives, extra: spec);
    return;
  }
  context.push(
    spec.isDaily ? Routes.daily() : Routes.play(spec.game, spec.level),
  );
}

class _LevelStartSheet extends ConsumerWidget {
  const _LevelStartSheet({required this.game, required this.level});
  final GameId game;
  final int level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final st = context.island(game);
    final spec = LevelConfig.forLevel(game, level);
    final rec = ref.watch(
      saveProvider.select((s) => s.progress(game).levels[level]),
    );
    final e = ref.watch(economyProvider);
    final relaxed = ref.watch(settingsProvider.select((s) => s.relaxed));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: st.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: st.ledge, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  '$level',
                  style: MiText.title.copyWith(
                    fontSize: 28,
                    color: st.onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: MiText.title.copyWith(fontSize: 26, color: c.ink),
                    ),
                    Row(
                      children: [
                        Text(
                          '${game.title} · ${spec.tier.label}',
                          style: MiText.small.copyWith(color: c.inkSoft),
                        ),
                        const SizedBox(width: 8),
                        TierPips(tier: spec.tier, color: st.color),
                      ],
                    ),
                  ],
                ),
              ),
              MiIconButton(
                icon: Icons.close_rounded,
                label: 'Close',
                background: c.page,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            decoration: BoxDecoration(
              color: c.isNight ? c.sunTint : const Color(0xFFFFF7EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  relaxed ? 'RELAXED MODE · ONE STAR' : 'EARN 3 STARS',
                  style: MiText.overline.copyWith(color: c.sunInk),
                ),
                const SizedBox(height: 4),
                _Goal(text: 'Solve the puzzle', done: rec != null),
                if (!relaxed)
                  _Goal(
                    text: 'Finish in under ${fmtTime(spec.parSeconds)}',
                    done: rec != null && rec.bestSeconds <= spec.parSeconds,
                  ),
                if (!relaxed)
                  _Goal(text: 'Use no hints', done: rec?.noHint ?? false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Fact(
                icon: Icons.schedule_rounded,
                iconColor: c.ink,
                value: relaxed ? 'Off' : fmtTime(spec.clockSeconds),
                label: relaxed ? 'clock' : 'per life',
              ),
              const SizedBox(width: 8),
              _Fact(
                icon: Icons.favorite_rounded,
                iconColor: c.heart,
                value: relaxed || rec != null ? '∞' : '${e.lives}',
                label: rec != null && !relaxed ? 'replay' : 'lives',
              ),
              const SizedBox(width: 8),
              _Fact(
                icon: Icons.lightbulb_rounded,
                iconColor: const Color(0xFFE0A100),
                value: '${e.hints}',
                label: 'hints',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rec == null
                ? 'First try on this level — no best time yet'
                : 'Your best: ${fmtTime(rec.bestSeconds)} · ${rec.stars} ${rec.stars == 1 ? 'star' : 'stars'}${relaxed ? '' : ' · replays never cost a life'}',
            textAlign: TextAlign.center,
            style: MiText.small.copyWith(color: c.inkSoft),
          ),
          const SizedBox(height: 14),
          MiButton(
            label: rec == null ? 'Start' : 'Play again',
            icon: Icons.play_arrow_rounded,
            color: st.color,
            ledge: st.ledge,
            onColor: st.onColor,
            onTap: () {
              Navigator.pop(context);
              startLevel(context, ref, spec);
            },
          ),
          MiTextButton(
            label: 'How to play ${game.title}',
            color: st.ink,
            onTap: () => showHowToPlay(context, game),
          ),
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.text, required this.done});
  final String text;
  final bool done;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Row(
      children: [
        StarShape(filled: true, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: MiText.label.copyWith(color: context.mi.ink, fontSize: 16),
          ),
        ),
        if (done)
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: context.mi.brandInk,
            semanticLabel: 'earned',
          ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.page,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            Text(
              value,
              style: MiText.headline.copyWith(fontSize: 18, color: c.ink),
            ),
            Text(label, style: MiText.caption.copyWith(color: c.inkSoft)),
          ],
        ),
      ),
    );
  }
}
