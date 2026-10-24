// Difficulty tuning for every level of every island, in one table.
//
// Why one place: clocks, par times and board sizes must be tuned together in
// play-testing. Engines take plain params; this file decides them per level.
// Puzzles are generated from a fixed seed per (game, level), so a level is the
// same puzzle on every phone and after a reinstall.

import 'game_id.dart';
import 'tier.dart';

/// Board-size knobs for each engine (mapped to the engines' own params classes).
class ThreadKnobs {
  const ThreadKnobs(this.size, this.extraNumbers);
  final int size;
  final int extraNumbers;
}

class QuiltKnobs {
  const QuiltKnobs(this.size, this.maxArea, this.shapeClues, this.shapeOnly);
  final int size;
  final int maxArea;
  final double shapeClues;
  final double shapeOnly;
}

class TwistKnobs {
  const TwistKnobs(this.rows, this.cols, this.minLen, this.maxLen);
  final int rows, cols, minLen, maxLen;
}

class SudokuKnobs {
  const SudokuKnobs(this.givens);
  final int givens;
}

/// Everything the play screen needs to start a level.
class LevelSpec {
  const LevelSpec({
    required this.game,
    required this.level,
    required this.seed,
    required this.tier,
    required this.parSeconds,
    required this.clockSeconds,
    required this.knobs,
    this.isDaily = false,
    this.dayKey,
  });

  final GameId game;

  /// 1..60 for island levels; 0 for the daily puzzle.
  final int level;
  final int seed;
  final Tier tier;

  /// Finish within this many seconds for the "beat the clock" star.
  final int parSeconds;

  /// Seconds on the clock for each life.
  final int clockSeconds;

  /// One of ThreadKnobs / QuiltKnobs / TwistKnobs / SudokuKnobs.
  final Object knobs;

  final bool isDaily;

  /// yyyy-MM-dd of the daily puzzle.
  final String? dayKey;
}

/// Builds [LevelSpec]s.
abstract final class LevelConfig {
  /// Spec of island level [level] (1..60) of [game].
  static LevelSpec forLevel(GameId game, int level) {
    final tier = Levels.tierOf(level);
    final ramp = Levels.rampOf(level);
    final knobs = _knobs(game, tier, ramp, level);
    final par = _par(game, tier, knobs);
    return LevelSpec(
      game: game,
      level: level,
      seed: levelSeed(game, level),
      tier: tier,
      parSeconds: par,
      clockSeconds: clockFor(par),
      knobs: knobs,
    );
  }

  /// Today's daily puzzle: the game rotates every day, difficulty is mid-Medium.
  static LevelSpec daily(DateTime localDay) {
    final days = DateTime.utc(localDay.year, localDay.month, localDay.day).millisecondsSinceEpoch ~/ 86400000;
    final game = GameId.values[days % GameId.values.length];
    final knobs = _knobs(game, Tier.medium, .5, 23);
    final par = _par(game, Tier.medium, knobs);
    final key = '${localDay.year.toString().padLeft(4, '0')}-${localDay.month.toString().padLeft(2, '0')}-${localDay.day.toString().padLeft(2, '0')}';
    return LevelSpec(
      game: game,
      level: 0,
      seed: 0x0DA11 * 31 + days * 7919,
      tier: Tier.medium,
      parSeconds: par,
      clockSeconds: clockFor(par),
      knobs: knobs,
      isDaily: true,
      dayKey: key,
    );
  }

  /// Stable per-level seed (never change: it would change every published level).
  static int levelSeed(GameId game, int level) => (game.index + 1) * 1000003 + level * 7919 + 0x5EED;

  /// Clock per life: generous enough that losing a life means "stuck", not "slow".
  static int clockFor(int par) {
    final raw = (par * 2.2).round();
    final rounded = ((raw + 14) ~/ 15) * 15;
    return rounded < 90 ? 90 : rounded;
  }

  static Object _knobs(GameId game, Tier tier, double ramp, int level) {
    switch (game) {
      case GameId.thread:
        return switch (tier) {
          Tier.easy => level <= 4 ? const ThreadKnobs(4, 2) : ThreadKnobs(5, ramp < .5 ? 2 : 1),
          Tier.medium => ThreadKnobs(6, ramp < .4 ? 2 : (ramp < .8 ? 1 : 0)),
          Tier.hard => ThreadKnobs(7, ramp < .5 ? 1 : 0),
          Tier.expert => ThreadKnobs(8, ramp < .3 ? 1 : 0),
        };
      case GameId.quilt:
        return switch (tier) {
          Tier.easy => QuiltKnobs(5, 6, ramp < .5 ? 0 : .1, 0),
          Tier.medium => const QuiltKnobs(6, 8, .2, 0),
          Tier.hard => QuiltKnobs(7, 10, .3, ramp < .5 ? .2 : .35),
          Tier.expert => QuiltKnobs(8, 12, .35, ramp < .5 ? .4 : .55),
        };
      case GameId.twist:
        return switch (tier) {
          Tier.easy => level <= 8 ? const TwistKnobs(4, 4, 4, 6) : const TwistKnobs(4, 5, 4, 6),
          Tier.medium => const TwistKnobs(5, 5, 4, 7),
          Tier.hard => const TwistKnobs(5, 6, 4, 8),
          Tier.expert => const TwistKnobs(6, 6, 4, 8),
        };
      case GameId.sudoku:
        final (hi, lo) = switch (tier) {
          Tier.easy => (20, 16),
          Tier.medium => (15, 13),
          Tier.hard => (12, 10),
          Tier.expert => (10, 8),
        };
        return SudokuKnobs((hi - (hi - lo) * ramp).round());
    }
  }

  static int _par(GameId game, Tier tier, Object knobs) {
    switch (game) {
      case GameId.thread:
        final size = (knobs as ThreadKnobs).size;
        return const {4: 25, 5: 45, 6: 75, 7: 110, 8: 150}[size]!;
      case GameId.quilt:
        final size = (knobs as QuiltKnobs).size;
        return const {5: 40, 6: 70, 7: 100, 8: 140}[size]!;
      case GameId.twist:
        final k = knobs as TwistKnobs;
        return const {16: 45, 20: 60, 25: 80, 30: 100, 36: 130}[k.rows * k.cols] ?? 90;
      case GameId.sudoku:
        return switch (tier) {
          Tier.easy => 60,
          Tier.medium => 90,
          Tier.hard => 120,
          Tier.expert => 150,
        };
    }
  }
}
