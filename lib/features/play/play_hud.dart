// The game frame's HUD (lives · clock · hints) and the shared action keys.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/pressable.dart';
import 'play_session.dart';
import '../../core/constants/plural.dart';

String clockText(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class PlayHud extends StatelessWidget {
  const PlayHud({
    super.key,
    required this.session,
    required this.lives,
    required this.hints,
    required this.style,
    this.showClock = true,
    this.livesKey,
    this.clockKey,
    this.hintsKey,
  });
  final PlaySession session;
  final int lives;
  final int hints;
  final IslandStyle style;
  final bool showClock;
  final Key? livesKey, clockKey, hintsKey;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final low = !session.relaxed && session.clockLeft <= 10;
        return Container(
          height: 54,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      key: livesKey,
                      child: Semantics(
                        label: session.relaxed
                            ? 'Relaxed mode, no lives'
                            : '${plural(lives, 'life', 'lives')} left',
                        excludeSemantics: true,
                        child: session.relaxed
                            ? Center(
                                child: Text(
                                  'Relaxed',
                                  style: MiText.label.copyWith(
                                    color: c.inkSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      child: AnimatedScale(
                                        scale: i < lives ? 1 : .8,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Icon(
                                          i < lives
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 21,
                                          color: i < lives
                                              ? c.heart
                                              : c.inkSoft.withValues(alpha: .5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    Container(width: 1.5, height: 32, color: c.line),
                    Expanded(
                      key: clockKey,
                      child: Semantics(
                        label: session.relaxed
                            ? 'No clock'
                            : '${session.clockLeft ~/ 60} minutes ${session.clockLeft % 60} seconds left',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              session.paused && !session.over
                                  ? Icons.pause_rounded
                                  : Icons.schedule_rounded,
                              size: 19,
                              color: low ? c.heart : style.ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !showClock && !low
                                  ? 'Hidden'
                                  : (session.relaxed
                                        ? clockText(session.elapsed)
                                        : clockText(session.clockLeft)),
                              style: MiText.title.copyWith(
                                fontSize: 21,
                                color: low ? c.heart : c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1.5, height: 32, color: c.line),
                    Expanded(
                      key: hintsKey,
                      child: Semantics(
                        label: plural(hints, 'hint'),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              size: 20,
                              color: Color(0xFFE0A100),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$hints',
                              style: MiText.title.copyWith(
                                fontSize: 19,
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!session.relaxed)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 4,
                  child: Container(
                    color: style.tint,
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 950),
                      widthFactor: session.clockFraction,
                      child: Container(color: low ? c.heart : style.color),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Chunky key (Undo / Hint / Reset) under the board.
class ActionKey extends StatelessWidget {
  const ActionKey({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
    this.sun = false,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final IslandStyle style;
  final bool sun;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final fg = sun ? const Color(0xFF13213C) : c.ink;
    return MiPressable(
      onTap: onTap,
      semanticLabel: badge == null ? label : '$label, $badge left',
      color: sun ? const Color(0xFFFFC233) : c.card,
      ledge: sun ? const Color(0xFFDB9A00) : style.cardLedge,
      radius: 20,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: MiText.small.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (badge != null)
            Positioned(
              top: -8,
              right: 6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF13213C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: MiText.caption.copyWith(
                    color: Colors.white,
                    fontFamily: MiFonts.display,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
