// One island in depth: progress ring, key numbers, solve-time trend vs par
// (line chart), the 12-week play habit (calendar heatmap), levels by tier,
// personal bests and this game's achievements.

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
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
import '../../domain/achievements.dart';
import '../../domain/game_id.dart';
import '../../domain/insights.dart';
import '../../domain/level_config.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import '../play/play_hud.dart' show clockText;
import '../../core/constants/plural.dart';

class GameInsightsScreen extends ConsumerStatefulWidget {
  const GameInsightsScreen({super.key, required this.game});
  final GameId game;
  @override
  ConsumerState<GameInsightsScreen> createState() => _GameInsightsScreenState();
}

class _GameInsightsScreenState extends ConsumerState<GameInsightsScreen> {
  InsightPeriod _period = InsightPeriod.month;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final g = widget.game;
    final st = context.island(g);
    final save = ref.watch(saveProvider);
    final now = ref.read(clockProvider)();
    final s = InsightsCalc.game(save, g, _period, now);
    final prog = save.progress(g);
    final achs = Achievements.states(save).where((a) => a.def.game == g).toList();
    final nextAch = achs.where((a) => !a.unlocked).firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Row(children: [
            MiIconButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => context.pop()),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: MiText.title.copyWith(fontSize: 24, color: c.ink)),
                Text(g.island, style: MiText.caption.copyWith(color: st.ink, fontWeight: FontWeight.w800)),
              ]),
            ),
            MiSegmented<InsightPeriod>(
              values: const [InsightPeriod.month, InsightPeriod.all],
              labelOf: (p) => p == InsightPeriod.month ? '30 days' : 'All',
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
              height: 36,
            ),
          ]),
          const SizedBox(height: 14),
          MiCard(
            child: Row(children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: prog.levels.length / Levels.perIsland),
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: 12, strokeCap: StrokeCap.round, color: st.color, backgroundColor: st.tint),
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${s.current}', style: MiText.number.copyWith(fontSize: 28, color: c.ink)),
                    Text('of ${Levels.perIsland}', style: MiText.caption.copyWith(color: c.inkSoft)),
                  ]),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(prog.completed ? 'Island complete!' : 'Climbing ${Levels.tierOf(s.current).label}', style: MiText.headline.copyWith(color: c.ink)),
                  const SizedBox(height: 4),
                  Text(_summary(s), style: MiText.small.copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [
              _Num('${s.solvedLevels}', 'Levels solved'),
              _Num(s.bestSeconds == null ? '—' : clockText(s.bestSeconds!), 'Best time'),
              _Num(s.averageSeconds == null ? '—' : clockText(s.averageSeconds!), 'Average'),
              _Num('${s.stars}', 'Stars'),
              _Num('${s.hints}', 'Hints used'),
              _Num('${s.livesLost}', 'Lives lost'),
            ],
          ),
          const SizedBox(height: 10),
          MiCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Solve time', style: MiText.headline.copyWith(color: c.ink)),
              const SizedBox(height: 2),
              Text(_trendLine(s), style: MiText.small.copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(height: 180, child: s.trend.length < 2 ? _Empty('Solve two levels to see your trend.') : _TrendChart(stats: s, style: st)),
            ]),
          ),
          const SizedBox(height: 10),
          MiCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your puzzle habit', style: MiText.headline.copyWith(color: c.ink)),
              const SizedBox(height: 2),
              Text(s.favouriteHour == null ? 'Last 12 weeks.' : 'Last 12 weeks · you play most around ${_hour(s.favouriteHour!)}.', style: MiText.small.copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _Heatmap(heat: s.heat, now: now),
            ]),
          ),
          const SizedBox(height: 10),
          MiCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Levels by tier', style: MiText.headline.copyWith(color: c.ink)),
              const SizedBox(height: 10),
              for (final t in s.tiers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 66, child: Text(t.tier.label, style: MiText.small.copyWith(color: t.locked ? c.inkSoft : c.ink, fontWeight: FontWeight.w800))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: t.solved / Levels.perTier, minHeight: 12, color: st.color, backgroundColor: t.locked ? c.sunk : st.tint),
                      ),
                    ),
                    SizedBox(
                      width: 86,
                      child: Text(t.locked ? 'Locked' : '${t.solved}/${Levels.perTier} · ${t.stars}★', textAlign: TextAlign.right, style: MiText.caption.copyWith(color: t.locked ? c.inkSoft : c.ink, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          MiCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Personal bests', style: MiText.headline.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              _Best('Fastest solve', s.bestSeconds == null ? '—' : '${clockText(s.bestSeconds!)} · Level ${s.bestLevel}'),
              _Best('Longest run without hints', '${s.longestNoHintRun} ${s.longestNoHintRun == 1 ? 'level' : 'levels'}'),
              _Best('Three-star levels', '${s.threeStarLevels} of ${s.solvedLevels}', last: true),
            ]),
          ),
          const SizedBox(height: 10),
          MiCard(
            onTap: () => context.push(Routes.achievements),
            semanticLabel: '${g.title} achievements',
            child: Row(children: [
              HexBadge(kind: achs.isEmpty ? BadgeKind.star : achs.first.def.kind, unlocked: achs.any((a) => a.unlocked), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${achs.where((a) => a.unlocked).length} of ${achs.length} ${g.title} achievements', style: MiText.label.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                  if (nextAch != null) Text('Next: ${nextAch.def.title} — ${nextAch.def.description}', style: MiText.caption.copyWith(color: c.inkSoft)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkSoft),
            ]),
          ),
        ]),
      ),
    );
  }

  String _summary(GameStats s) {
    final easyMed = s.tiers.take(2).fold(0, (n, t) => n + t.stars);
    final next = Tier.values.firstWhere((t) => t.firstLevel > s.current, orElse: () => Tier.expert);
    return '${plural(s.stars, 'star')} so far${easyMed > 0 ? ' ($easyMed in Easy and Medium)' : ''}. ${next.firstLevel > s.current ? '${next.label} opens at level ${next.firstLevel}.' : 'You are on the last tier.'}';
  }

  String _trendLine(GameStats s) {
    if (s.trend.length < 4) return 'Your last ${s.trend.length} solved levels.';
    final half = s.trend.length ~/ 2;
    double avg(Iterable<(int, int)> xs) => xs.fold(0, (n, x) => n + x.$2) / xs.length;
    final a = avg(s.trend.take(half)), b = avg(s.trend.skip(s.trend.length - half));
    return 'Average went from ${clockText(a.round())} to ${clockText(b.round())} over your last ${s.trend.length} levels.';
  }

  static String _hour(int h) => h == 0 ? 'midnight' : (h < 12 ? '$h AM' : (h == 12 ? 'noon' : '${h - 12} PM'));
}

class _Num extends StatelessWidget {
  const _Num(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => MiCard(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          FittedBox(child: Text(value, style: MiText.number.copyWith(color: context.mi.ink))),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: MiText.caption.copyWith(color: context.mi.inkSoft)),
        ]),
      );
}

class _Best extends StatelessWidget {
  const _Best(this.label, this.value, {this.last = false});
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: context.mi.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: MiText.label.copyWith(color: context.mi.ink))),
          Text(value, style: MiText.label.copyWith(color: context.mi.ink, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: MiText.small.copyWith(color: context.mi.inkSoft)));
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.stats, required this.style});
  final GameStats stats;
  final IslandStyle style;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final pts = stats.trend;
    final par = LevelConfig.forLevel(stats.game, pts.last.$1).parSeconds.toDouble();
    final ys = [...pts.map((p) => p.$2.toDouble()), par];
    final lo = max(0.0, (ys.reduce(min) / 30).floor() * 30.0 - 30);
    final hi = (ys.reduce(max) / 30).ceil() * 30.0 + 30;
    return Semantics(
      label: 'Solve times for levels ${pts.first.$1} to ${pts.last.$1}, par ${clockText(par.round())}.',
      excludeSemantics: true,
      child: LineChart(
        LineChartData(
          minY: lo,
          maxY: hi,
          minX: 0,
          maxX: (pts.length - 1).toDouble(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (hi - lo) / 2, getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: (hi - lo) / 2, getTitlesWidget: (v, _) => Text(clockText(v.round()), style: MiText.caption.copyWith(color: c.inkSoft))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i != 0 && i != pts.length - 1 && i != (pts.length - 1) ~/ 2) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text('Lv ${pts[i].$1}', style: MiText.caption.copyWith(color: c.inkSoft)));
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: par,
              color: c.inkSoft,
              strokeWidth: 1.5,
              dashArray: const [5, 5],
              label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: MiText.caption.copyWith(color: c.inkSoft, fontWeight: FontWeight.w800), labelResolver: (_) => 'Par ${clockText(par.round())}'),
            ),
          ]),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.isNight ? c.sunk : c.navy,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('Level ${pts[s.x.toInt()].$1}\n', MiText.caption.copyWith(color: const Color(0xFFC9D6EA)), children: [
                    TextSpan(text: clockText(s.y.round()), style: MiText.label.copyWith(fontFamily: MiFonts.display, color: Colors.white)),
                  ]),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].$2.toDouble())],
              color: style.color,
              barWidth: 2,
              dotData: FlDotData(show: true, getDotPainter: (_, _, _, i) => FlDotCirclePainter(radius: i == pts.length - 1 ? 5 : 3, color: style.color, strokeWidth: 2, strokeColor: c.card)),
              belowBarData: BarAreaData(show: true, color: style.tint.withValues(alpha: .6)),
            ),
          ],
        ),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 600),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.heat, required this.now});
  final List<int> heat;
  final DateTime now;

  static const _ramp = [Color(0xFFE3ECF5), Color(0xFFBFE8E1), Color(0xFF7FD0C4), Color(0xFF2FA597), Color(0xFF0A7C70)];
  static const _rampNight = [Color(0xFF24324D), Color(0xFF1B4A47), Color(0xFF1F6B63), Color(0xFF2FA597), Color(0xFF5FD6C5)];

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final ramp = c.isNight ? _rampNight : _ramp;
    // Columns are weeks (Mon..Sun rows); the last column ends today.
    final todayRow = now.weekday - 1;
    final cells = 7 * 12;
    int? valueAt(int col, int row) {
      final fromEnd = (11 - col) * 7 + (todayRow - row);
      if (fromEnd < 0) return null; // future days this week
      final idx = 83 - fromEnd;
      return idx >= 0 && idx < heat.length ? heat[idx] : 0;
    }

    int level(int v) => v == 0 ? 0 : (v == 1 ? 1 : (v == 2 ? 2 : (v <= 4 ? 3 : 4)));
    return Semantics(
      label: 'Calendar of puzzles solved per day for the last 12 weeks. ${heat.where((v) => v > 0).length} active days.',
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, box) {
        final size = min(20.0, (box.maxWidth - 34) / 12 - 3);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 34,
              child: Column(children: [
                for (var r = 0; r < 7; r++) SizedBox(height: size + 3, child: Text(const ['Mon', '', 'Wed', '', 'Fri', '', 'Sun'][r], style: MiText.caption.copyWith(fontSize: 11, color: c.inkSoft))),
              ]),
            ),
            for (var col = 0; col < 12; col++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Column(children: [
                  for (var r = 0; r < 7; r++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: valueAt(col, r) == null ? Colors.transparent : ramp[level(valueAt(col, r)!)],
                          borderRadius: BorderRadius.circular(4),
                          border: col == 11 && r == todayRow ? Border.all(color: c.ink, width: 2) : null,
                        ),
                      ),
                    ),
                ]),
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('Less', style: MiText.caption.copyWith(color: c.inkSoft)),
            const SizedBox(width: 4),
            for (final col in ramp) Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3))),
            Text('More', style: MiText.caption.copyWith(color: c.inkSoft)),
            const Spacer(),
            Text(plural(cells, 'day'), style: MiText.caption.copyWith(color: c.inkSoft)),
          ]),
        ]);
      }),
    );
  }
}
