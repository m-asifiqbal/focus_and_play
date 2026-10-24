// Numbers behind the Insights tab, derived from the attempt log and level records.

import 'dart:math';

import 'game_id.dart';
import 'rules.dart';
import 'save_data.dart';
import 'tier.dart';

enum InsightPeriod {
  week('Week', 7),
  month('Month', 30),
  all('All', 100000);

  const InsightPeriod(this.label, this.days);
  final String label;
  final int days;
}

/// Overview card numbers for one period.
class OverviewStats {
  const OverviewStats({
    required this.solved,
    required this.solvedAllTime,
    required this.streak,
    required this.bestStreak,
    required this.stars,
    required this.possibleStars,
    required this.seconds,
    required this.lastSevenDays,
    required this.timeByGame,
    required this.solvedByGame,
  });
  final int solved,
      solvedAllTime,
      streak,
      bestStreak,
      stars,
      possibleStars,
      seconds;

  /// Solved puzzles for each of the last 7 days, oldest first (index 6 = today).
  final List<int> lastSevenDays;
  final Map<GameId, int> timeByGame;
  final Map<GameId, int> solvedByGame;

  double get dailyMinutes => seconds / 60 / 7;
}

/// One tier row of the per-game detail.
class TierRow {
  const TierRow(this.tier, this.solved, this.stars, this.locked);
  final Tier tier;
  final int solved, stars;
  final bool locked;
}

/// Per-game detail numbers.
class GameStats {
  const GameStats({
    required this.game,
    required this.current,
    required this.solvedLevels,
    required this.solvedInPeriod,
    required this.bestSeconds,
    required this.bestLevel,
    required this.averageSeconds,
    required this.stars,
    required this.hints,
    required this.livesLost,
    required this.trend,
    required this.heat,
    required this.tiers,
    required this.threeStarLevels,
    required this.longestNoHintRun,
    required this.favouriteHour,
  });
  final GameId game;
  final int current, solvedLevels, solvedInPeriod;
  final int? bestSeconds, bestLevel, averageSeconds;
  final int stars, hints, livesLost;

  /// (level, seconds) of the last up-to-15 solved island levels, oldest first.
  final List<(int, int)> trend;

  /// Solves per day for the last 84 days (12 weeks), oldest first; index 83 = today.
  final List<int> heat;
  final List<TierRow> tiers;
  final int threeStarLevels, longestNoHintRun;

  /// Local hour (0..23) with the most solves, or null with no data.
  final int? favouriteHour;
}

abstract final class InsightsCalc {
  static bool _inPeriod(Attempt a, InsightPeriod p, DateTime now) =>
      daysBetween(DateTime.fromMillisecondsSinceEpoch(a.at), now) < p.days;

  static OverviewStats overview(SaveData s, InsightPeriod p, DateTime now) {
    final inP = s.attempts.where((a) => _inPeriod(a, p, now)).toList();
    final solved = inP.where((a) => a.solved).toList();
    final seven = List<int>.filled(7, 0);
    for (final a in s.attempts.where((a) => a.solved)) {
      final d = daysBetween(DateTime.fromMillisecondsSinceEpoch(a.at), now);
      if (d >= 0 && d < 7) seven[6 - d]++;
    }
    return OverviewStats(
      solved: solved.length,
      solvedAllTime: s.attempts.where((a) => a.solved).length,
      streak: StreakRules.current(s, now),
      bestStreak: StreakRules.best(s),
      stars: solved.fold(0, (n, a) => n + a.stars),
      possibleStars: solved.length * 3,
      seconds: inP.fold(0, (n, a) => n + a.seconds),
      lastSevenDays: seven,
      timeByGame: {
        for (final g in GameId.values)
          g: inP.where((a) => a.game == g).fold(0, (n, a) => n + a.seconds),
      },
      solvedByGame: {
        for (final g in GameId.values)
          g: solved.where((a) => a.game == g).length,
      },
    );
  }

  static GameStats game(SaveData s, GameId g, InsightPeriod p, DateTime now) {
    final prog = s.progress(g);
    final all = s.attempts.where((a) => a.game == g).toList();
    final inP = all.where((a) => _inPeriod(a, p, now)).toList();
    final solvedP = inP.where((a) => a.solved).toList();
    int? best, bestLevel;
    for (final e in prog.levels.entries) {
      if (best == null || e.value.bestSeconds < best) {
        best = e.value.bestSeconds;
        bestLevel = e.key;
      }
    }
    final island = all.where((a) => a.solved && !a.daily).toList();
    final trend = [
      for (final a in island.skip(max(0, island.length - 15)))
        (a.level, a.seconds),
    ];
    final heat = List<int>.filled(84, 0);
    for (final a in all.where((a) => a.solved)) {
      final d = daysBetween(DateTime.fromMillisecondsSinceEpoch(a.at), now);
      if (d >= 0 && d < 84) heat[83 - d]++;
    }
    final hours = List<int>.filled(24, 0);
    for (final a in all.where((a) => a.solved)) {
      hours[DateTime.fromMillisecondsSinceEpoch(a.at).hour]++;
    }
    final topHour = hours.reduce(max);
    var run = 0, longest = 0;
    for (final a in all.where((a) => a.solved)) {
      run = a.hints == 0 ? run + 1 : 0;
      longest = max(longest, run);
    }
    return GameStats(
      game: g,
      current: prog.current,
      solvedLevels: prog.levels.length,
      solvedInPeriod: solvedP.length,
      bestSeconds: best,
      bestLevel: bestLevel,
      averageSeconds: solvedP.isEmpty
          ? null
          : (solvedP.fold(0, (n, a) => n + a.seconds) / solvedP.length).round(),
      stars: prog.stars,
      hints: inP.fold(0, (n, a) => n + a.hints),
      livesLost: inP.fold(0, (n, a) => n + a.livesLost),
      trend: trend,
      heat: heat,
      tiers: [
        for (final t in Tier.values)
          TierRow(
            t,
            prog.levels.keys.where((l) => Levels.tierOf(l) == t).length,
            prog.levels.entries
                .where((e) => Levels.tierOf(e.key) == t)
                .fold(0, (n, e) => n + e.value.stars),
            prog.current < t.firstLevel,
          ),
      ],
      threeStarLevels: prog.levels.values.where((r) => r.stars >= 3).length,
      longestNoHintRun: longest,
      favouriteHour: topHour == 0 ? null : hours.indexOf(topHour),
    );
  }
}
