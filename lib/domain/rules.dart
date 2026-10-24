// Game rules that don't belong to a single puzzle: lives refill, free hints,
// stars, XP and the daily streak. Pure functions of (state, now) so they are
// easy to test and behave the same after the app was killed for a week.

import 'dart:math';

import 'save_data.dart';
import 'tier.dart';

/// yyyy-MM-dd of a local date.
String dayKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

/// Local midnight of [d].
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days between two local dates (DST-safe: compares calendar dates).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

abstract final class EconomyRules {
  static const _period = Economy.refillMinutes * 60 * 1000;

  /// Applies lives refilled since the stamp and the once-a-day free-hint top-up.
  static Economy normalise(Economy e, DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    var out = e;
    if (e.lives >= Economy.maxLives) {
      out = out.copyWith(lives: Economy.maxLives, livesStampMs: ms);
    } else {
      final stamp = e.livesStampMs == 0 ? ms : e.livesStampMs;
      final gained = max(0, (ms - stamp) ~/ _period);
      final lives = min(Economy.maxLives, e.lives + gained);
      out = out.copyWith(lives: lives, livesStampMs: lives >= Economy.maxLives ? ms : stamp + gained * _period);
    }
    final today = dayKey(now);
    if (out.hintDay != today) {
      out = out.copyWith(hints: max(out.hints, Economy.dailyFreeHints), hintDay: today);
    }
    return out;
  }

  /// Time until the next life comes back, or null when lives are full.
  static Duration? nextLifeIn(Economy e, DateTime now) {
    final n = normalise(e, now);
    if (n.lives >= Economy.maxLives) return null;
    final left = n.livesStampMs + _period - now.millisecondsSinceEpoch;
    return Duration(milliseconds: max(0, left));
  }

  /// When all lives will be back (for the "lives are full" notification).
  static DateTime? fullAt(Economy e, DateTime now) {
    final n = normalise(e, now);
    if (n.lives >= Economy.maxLives) return null;
    final missing = Economy.maxLives - n.lives;
    return DateTime.fromMillisecondsSinceEpoch(n.livesStampMs + missing * _period);
  }

  /// Spends one life. The refill clock starts now if lives were full.
  static Economy loseLife(Economy e, DateTime now) {
    final n = normalise(e, now);
    if (n.lives <= 0) return n;
    final wasFull = n.lives >= Economy.maxLives;
    return n.copyWith(lives: n.lives - 1, livesStampMs: wasFull ? now.millisecondsSinceEpoch : n.livesStampMs);
  }

  static Economy addLife(Economy e, DateTime now) {
    final n = normalise(e, now);
    final lives = min(Economy.maxLives, n.lives + 1);
    return n.copyWith(lives: lives, livesStampMs: lives >= Economy.maxLives ? now.millisecondsSinceEpoch : n.livesStampMs);
  }

  static Economy addHints(Economy e, int count) => e.copyWith(hints: min(Economy.maxHints, e.hints + count));

  static Economy spendHint(Economy e) => e.copyWith(hints: max(0, e.hints - 1));
}

abstract final class ScoreRules {
  /// Stars: 1 for solving, +1 for beating par, +1 for no hints. Relaxed mode caps at 1.
  static int stars({required bool relaxed, required int seconds, required int par, required int hints}) {
    if (relaxed) return 1;
    return 1 + (seconds <= par ? 1 : 0) + (hints == 0 ? 1 : 0);
  }

  /// XP for a solve. Harder tiers and the daily puzzle are worth more.
  static int xp({required int stars, required Tier tier, bool daily = false, bool firstSolve = true}) {
    final base = 10 + stars * 10 + tier.index * 5 + (daily ? 20 : 0);
    return firstSolve ? base : (base / 4).round();
  }

  /// Hints granted when a tier chest (levels 15, 30, 45, 60) is opened.
  static int chestHints(Tier tier) => 3 + tier.index;
}

abstract final class StreakRules {
  /// Local days (yyyy-MM-dd) on which the player solved at least one puzzle.
  static Set<String> solvedDays(SaveData s) => {
        for (final a in s.attempts)
          if (a.solved) dayKey(DateTime.fromMillisecondsSinceEpoch(a.at)),
        ...s.daily.keys,
      };

  /// Current streak: consecutive days ending today (or yesterday, so the streak
  /// isn't shown as broken before the player has played today).
  static int current(SaveData s, DateTime now) {
    final days = solvedDays(s);
    var d = dayStart(now);
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// Longest streak ever.
  static int best(SaveData s) {
    final sorted = solvedDays(s).map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && daysBetween(prev, d) == 1) ? run + 1 : 1;
      best = max(best, run);
      prev = d;
    }
    return best;
  }
}
