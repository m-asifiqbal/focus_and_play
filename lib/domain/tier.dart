// Difficulty tiers and the island's level layout.
//
// Every island has 60 levels in four tiers of 15 (Easy → Medium → Hard → Expert).
// The last level of each tier is a "gate" with a treasure chest.

/// Difficulty tier of a level.
enum Tier {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
    Tier.easy => 'Easy',
    Tier.medium => 'Medium',
    Tier.hard => 'Hard',
    Tier.expert => 'Expert',
  };

  /// 1..4 — drawn as pips next to the tier name.
  int get pips => index + 1;

  int get firstLevel => index * Levels.perTier + 1;
  int get lastLevel => (index + 1) * Levels.perTier;
}

/// Level-count constants and helpers.
abstract final class Levels {
  static const perTier = 15;
  static const perIsland = 60;

  /// Tier of a 1-based level number.
  static Tier tierOf(int level) =>
      Tier.values[((level - 1) ~/ perTier).clamp(0, 3)];

  /// 0..1 progress of a level inside its tier, so difficulty ramps smoothly.
  static double rampOf(int level) => ((level - 1) % perTier) / (perTier - 1);

  /// Last level of a tier: solving it opens the tier chest.
  static bool isGate(int level) => level % perTier == 0;

  /// 1..15 index of the level inside its tier.
  static int indexInTier(int level) => (level - 1) % perTier + 1;
}
