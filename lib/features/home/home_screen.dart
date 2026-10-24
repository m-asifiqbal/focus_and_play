// Home: greeting, today's daily puzzle with the week's streak, and the four
// island cards. The banner ad sits at the bottom, clear of everything tappable.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/pinned_page.dart';
import '../../domain/game_id.dart';
import '../../domain/level_config.dart';
import '../../domain/rules.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import '../island/level_start_sheet.dart';
import '../onboarding/widgets/game_preview.dart';
import 'widgets/mini_island.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(DateTime now) => now.hour < 12
      ? 'Good morning'
      : (now.hour < 17 ? 'Good afternoon' : 'Good evening');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final now = ref.watch(clockProvider)();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: PinnedPage(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              header: Row(
                children: [
                  BadgeAvatar(badge: profile.badge),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(now),
                          style: MiText.caption.copyWith(color: c.inkSoft),
                        ),
                        Text(
                          profile.name.isEmpty ? 'Puzzler' : profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MiText.title.copyWith(color: c.ink),
                        ),
                      ],
                    ),
                  ),
                  const EconomyPills(),
                ],
              ),
              children: [
                const _DailyCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your islands',
                        style: MiText.title.copyWith(
                          fontSize: 20,
                          color: c.ink,
                        ),
                      ),
                    ),
                    Text(
                      'Tap an island to explore',
                      style: MiText.caption.copyWith(color: c.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .98,
                  children: [
                    for (final (i, g) in GameId.values.indexed)
                      _IslandCard(game: g)
                          .animate()
                          .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                          .slideY(begin: .08, curve: Curves.easeOut),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 10),
            child: BannerAdSlot(),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends ConsumerWidget {
  const _DailyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    // Rebuilds on a new day or a new solve — not every second (only _NewIn ticks).
    final now = ref.watch(todayProvider);
    final spec = LevelConfig.daily(now);
    final st = context.island(spec.game);
    final done = ref.watch(saveProvider.select((s) => s.daily[spec.dayKey]));
    final days = ref.watch(solvedDaysProvider);
    final streak = StreakRules.currentFrom(days, now);
    final monday = dayStart(now).subtract(Duration(days: now.weekday - 1));
    final weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return MiCard(
      ledge: c.ledge,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.sunTint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Color(0xFFF0582A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streak == 0 ? 'Start a streak' : '$streak-day streak',
                      style: MiText.caption.copyWith(
                        color: c.sunInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.schedule_rounded, size: 15, color: c.inkSoft),
              const SizedBox(width: 4),
              const _NewIn(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY PUZZLE · ${spec.game.title.toUpperCase()}',
                      style: MiText.overline.copyWith(color: st.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${DateFormat('EEEE').format(now)}'s ${spec.game.title}",
                      style: MiText.title.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done == null
                          ? 'Medium · about ${(spec.parSeconds / 60).ceil()} min'
                          : 'Solved in ${_fmt(done.seconds)} · come back tomorrow',
                      style: MiText.small.copyWith(
                        color: c.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GamePreview(game: spec.game, size: 64),
                  if (done != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.card, width: 3),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'This week: ${[for (var i = 0; i < 7; i++)
                  if (days.contains(dayKey(monday.add(Duration(days: i))))) weekLabels[i]].length} days played',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _DayDot(
                        day: DateTime(
                          monday.year,
                          monday.month,
                          monday.day + i,
                        ),
                        label: weekLabels[i],
                        played: days,
                        now: now,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (done == null)
            MiButton(
              label: "Play today's puzzle",
              icon: Icons.play_arrow_rounded,
              height: 50,
              onTap: () => startLevel(context, ref, spec),
            )
          else
            MiGhostButton(
              label: 'Play it again (just for fun)',
              icon: Icons.replay_rounded,
              onTap: () => startLevel(context, ref, spec),
            ),
        ],
      ),
    );
  }

  static String _fmt(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "New in 3h 45m" — the only part of the daily card that ticks.
class _NewIn extends ConsumerWidget {
  const _NewIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secondTickerProvider);
    final now = ref.read(clockProvider)();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    return Text(
      'New in ${left.inHours}h ${left.inMinutes % 60}m',
      style: MiText.caption.copyWith(color: context.mi.inkSoft),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.label,
    required this.played,
    required this.now,
  });
  final DateTime day;
  final String label;
  final Set<String> played;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final isToday = dayKey(day) == dayKey(now);
    final done = played.contains(dayKey(day));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 30,
      decoration: BoxDecoration(
        color: done ? c.sun : (isToday ? c.card : c.sunk),
        borderRadius: BorderRadius.circular(15),
        border: isToday && !done
            ? Border.all(color: c.brandInk, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF13213C))
          : Text(
              label,
              style: MiText.small.copyWith(
                fontFamily: MiFonts.display,
                color: isToday ? c.brandInk : c.inkSoft,
              ),
            ),
    );
  }
}

class _IslandCard extends ConsumerWidget {
  const _IslandCard({required this.game});
  final GameId game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final st = context.island(game);
    final prog = ref.watch(saveProvider.select((s) => s.progress(game)));
    final level = prog.current;
    final frac = prog.levels.length / Levels.perIsland;
    return MiCard(
      onTap: () => context.push(Routes.island(game)),
      semanticLabel:
          '${game.title} on ${game.island}, level $level, ${Levels.tierOf(level).label}',
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MiniIsland(
                game: game,
                night: c.isNight,
                height: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: MiText.headline.copyWith(fontSize: 18, color: c.ink),
                ),
                Text(
                  '${game.island} · Lv $level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MiText.caption.copyWith(color: c.inkSoft),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac.clamp(0.02, 1.0),
                    minHeight: 6,
                    backgroundColor: st.tint,
                    color: st.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
