// Insights overview: headline numbers for the period, solves per day (bar
// chart with tooltips), where the time went (per island), the four islands and
// the latest achievements. Banner ad at the bottom.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/pinned_page.dart';
import '../../domain/achievements.dart';
import '../../domain/game_id.dart';
import '../../domain/insights.dart';
import '../../state/save_controller.dart';
import '../../core/constants/plural.dart';

class InsightPeriodNotifier extends Notifier<InsightPeriod> {
  @override
  InsightPeriod build() => InsightPeriod.week;
  void set(InsightPeriod p) => state = p;
}

final insightPeriodProvider =
    NotifierProvider<InsightPeriodNotifier, InsightPeriod>(
      InsightPeriodNotifier.new,
    );

String hm(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final period = ref.watch(insightPeriodProvider);
    final save = ref.watch(saveProvider);
    final now = ref.read(clockProvider)();
    final o = InsightsCalc.overview(save, period, now);
    final ach = Achievements.states(save);
    final earned = ach.where((a) => a.unlocked).toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: PinnedPage(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              header: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Insights',
                      style: MiText.display.copyWith(
                        fontSize: 28,
                        color: c.ink,
                      ),
                    ),
                  ),
                  MiSegmented<InsightPeriod>(
                    values: InsightPeriod.values,
                    labelOf: (p) => p.label,
                    selected: period,
                    onChanged: ref.read(insightPeriodProvider.notifier).set,
                    height: 36,
                  ),
                ],
              ),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: [
                    _Tile(
                      label: 'Puzzles solved',
                      value: '${o.solved}',
                      sub: '${o.solvedAllTime} all time',
                    ),
                    _Tile(
                      label: 'Daily streak',
                      value: '${o.streak}',
                      sub: 'Best ever ${plural(o.bestStreak, 'day')}',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    _Tile(
                      label: 'Stars earned',
                      value: '${o.stars}',
                      sub: 'of ${o.possibleStars} possible',
                    ),
                    _Tile(
                      label: 'Time played',
                      value: hm(o.seconds),
                      sub: period == InsightPeriod.week
                          ? (o.dailyMinutes < 1
                                ? 'under a minute a day'
                                : 'about ${o.dailyMinutes.round()} min a day')
                          : period.label.toLowerCase(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Puzzles solved per day',
                              style: MiText.headline.copyWith(color: c.ink),
                            ),
                          ),
                          Text(
                            'Last 7 days',
                            style: MiText.caption.copyWith(color: c.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 170,
                        child: _DaysChart(counts: o.lastSevenDays, now: now),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _busiest(o.lastSevenDays, now),
                        style: MiText.caption.copyWith(color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Where your time went',
                              style: MiText.headline.copyWith(color: c.ink),
                            ),
                          ),
                          Text(
                            hm(o.seconds),
                            style: MiText.caption.copyWith(color: c.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SplitBar(values: o.timeByGame),
                      const SizedBox(height: 10),
                      Wrap(
                        runSpacing: 6,
                        children: [
                          for (final g in GameId.values)
                            SizedBox(
                              width:
                                  (MediaQuery.sizeOf(context).width - 72) / 2,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: context.island(g).color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      style: MiText.small.copyWith(
                                        color: c.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    hm(o.timeByGame[g] ?? 0),
                                    style: MiText.small.copyWith(
                                      color: c.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your islands',
                  style: MiText.title.copyWith(fontSize: 20, color: c.ink),
                ),
                const SizedBox(height: 10),
                for (final g in GameId.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MiCard(
                      onTap: () => context.push(Routes.gameInsights(g)),
                      semanticLabel: '${g.title} insights',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: context.island(g).tint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              gameIcon(g),
                              color: context.island(g).ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: MiText.headline.copyWith(color: c.ink),
                                ),
                                Text(
                                  '${g.island} · Level ${save.progress(g).current}',
                                  style: MiText.caption.copyWith(
                                    color: c.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${o.solvedByGame[g]}',
                                style: MiText.headline.copyWith(color: c.ink),
                              ),
                              Text(
                                'solved',
                                style: MiText.caption.copyWith(
                                  color: c.inkSoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, color: c.inkSoft),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                MiCard(
                  onTap: () => context.push(Routes.achievements),
                  semanticLabel:
                      'Achievements, ${earned.length} of ${ach.length}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Achievements',
                              style: MiText.headline.copyWith(color: c.ink),
                            ),
                          ),
                          Text(
                            '${earned.length} of ${ach.length} · See all',
                            style: MiText.small.copyWith(
                              color: c.brandInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final a in [
                            ...earned,
                            ...ach.where((x) => !x.unlocked),
                          ].take(5))
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: HexBadge(
                                kind: a.def.kind,
                                unlocked: a.unlocked,
                                size: 46,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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

  static String _busiest(List<int> counts, DateTime now) {
    final max = counts.fold(0, (a, b) => b > a ? b : a);
    if (max == 0) return 'Solve a puzzle and your week will show up here.';
    final i = counts.lastIndexOf(max);
    final day = DateTime(now.year, now.month, now.day - (6 - i));
    return 'Your busiest day was ${i == 6 ? 'today' : DateFormat('EEEE').format(day)}. Tap a bar for details.';
  }
}

IconData gameIcon(GameId g) => switch (g) {
  GameId.thread => Icons.gesture_rounded,
  GameId.quilt => Icons.grid_view_rounded,
  GameId.twist => Icons.abc_rounded,
  GameId.sudoku => Icons.apps_rounded,
  GameId.sleuth => Icons.search_rounded,
  GameId.bridges => Icons.timeline_rounded,
};

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    this.icon,
  });
  final String label, value, sub;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return Semantics(
      label: '$label: $value, $sub',
      excludeSemantics: true,
      child: MiCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: MiText.caption.copyWith(
                color: c.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: MiText.number.copyWith(fontSize: 30, color: c.ink),
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(icon, color: const Color(0xFFF0582A), size: 22),
              ],
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MiText.caption.copyWith(color: c.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysChart extends StatelessWidget {
  const _DaysChart({required this.counts, required this.now});
  final List<int> counts;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final maxV = counts.fold(0, (a, b) => b > a ? b : a);
    final top = (maxV < 4 ? 4 : ((maxV + 3) ~/ 4) * 4).toDouble();
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(now.year, now.month, now.day - (6 - i)),
    ];
    return Semantics(
      label:
          'Puzzles solved per day: ${[for (var i = 0; i < 7; i++) '${DateFormat('EEEE').format(days[i])} ${counts[i]}'].join(', ')}',
      excludeSemantics: true,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.line, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: top / 2,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: MiText.caption.copyWith(color: c.inkSoft),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  final today = i == 6;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      today
                          ? 'Today'
                          : DateFormat('E').format(days[i]).substring(0, 1),
                      style: MiText.caption.copyWith(
                        color: today ? c.ink : c.inkSoft,
                        fontWeight: today ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.isNight ? c.sunk : c.navy,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                '${DateFormat('EEEE').format(days[g.x])}\n',
                MiText.caption.copyWith(color: const Color(0xFFC9D6EA)),
                children: [
                  TextSpan(
                    text: '${rod.toY.toInt()} solved',
                    style: MiText.label.copyWith(
                      fontFamily: MiFonts.display,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < 7; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    width: 22,
                    color: i == 6 ? c.brandLedge : c.brand,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 600),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.values});
  final Map<GameId, int> values;
  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final total = values.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return Container(
        height: 16,
        decoration: BoxDecoration(
          color: c.sunk,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    final parts = [
      for (final g in GameId.values)
        if ((values[g] ?? 0) > 0) g,
    ];
    return Semantics(
      label:
          'Time by game: ${[for (final g in parts) '${g.title} ${hm(values[g]!)}'].join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (i, g) in parts.indexed)
            Expanded(
              flex: (values[g]! * 1000 ~/ total).clamp(1, 1000),
              child: Container(
                height: 16,
                margin: EdgeInsets.only(right: i == parts.length - 1 ? 0 : 2),
                decoration: BoxDecoration(
                  color: context.island(g).color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
