// Achievement catalogue and progress, computed from the save data.
//
// Why computed: progress (e.g. "8 of 15") is always derived from levels and the
// attempt log, so it can never drift from what the player actually did. Only the
// unlock time is stored, so a badge stays earned once earned.

import 'dart:math';

import 'game_id.dart';
import 'level_config.dart';
import 'rules.dart';
import 'save_data.dart';
import 'tier.dart';

/// Visual family of a badge (the UI picks colour + glyph from it).
enum BadgeKind {
  thread,
  quilt,
  twist,
  sudoku,
  sleuth,
  bridges,
  streak,
  star,
  moon,
  sun,
  hint,
  crown,
  heart,
  island,
}

class AchievementDef {
  const AchievementDef(
    this.id,
    this.title,
    this.description,
    this.kind,
    this.target,
    this.measure, {
    this.rewardHints = 2,
    this.game,
  });
  final String id;
  final String title;
  final String description;
  final BadgeKind kind;
  final int target;

  /// Current progress (capped at [target] by the caller).
  final int Function(SaveData s) measure;
  final int rewardHints;
  final GameId? game;
}

/// Progress of one achievement.
class AchievementState {
  const AchievementState(this.def, this.current, this.unlockedAt);
  final AchievementDef def;
  final int current;
  final int? unlockedAt;
  bool get unlocked => unlockedAt != null;
  double get fraction => min(1, current / def.target);
}

int _solvedLevels(SaveData s, GameId g) => s.progress(g).levels.length;

int _swift(SaveData s, GameId g) =>
    s.attempts.any(
      (a) =>
          a.solved &&
          !a.daily &&
          a.game == g &&
          Levels.tierOf(a.level) == Tier.hard &&
          a.seconds <= LevelConfig.forLevel(g, a.level).parSeconds,
    )
    ? 1
    : 0;

int _longestNoHintRun(SaveData s) {
  var best = 0, run = 0;
  for (final a in s.attempts.where((a) => a.solved)) {
    run = a.hints == 0 ? run + 1 : 0;
    best = max(best, run);
  }
  return best;
}

int _hourSolve(
  SaveData s,
  bool Function(int hour) test, {
  bool dailyOnly = false,
}) =>
    s.attempts.any((a) {
      if (!a.solved || (dailyOnly && !a.daily)) return false;
      return test(DateTime.fromMillisecondsSinceEpoch(a.at).hour);
    })
    ? 1
    : 0;

int _threeStarLevels(SaveData s, [GameId? g]) =>
    (g == null ? s.games.values : [s.progress(g)]).fold(
      0,
      (n, p) => n + p.levels.values.where((r) => r.stars >= 3).length,
    );

int _islandsVisited(SaveData s) =>
    GameId.values.where((g) => s.progress(g).levels.isNotEmpty).length;

int _bestIsland(SaveData s) =>
    GameId.values.fold(0, (m, g) => max(m, s.progress(g).levels.length));

int _reachedExpert(SaveData s) =>
    GameId.values.any((g) => s.progress(g).current >= Tier.expert.firstLevel)
    ? 1
    : 0;

int _steady(SaveData s) =>
    s.attempts.any(
      (a) =>
          a.solved &&
          !a.daily &&
          a.level >= Tier.hard.firstLevel &&
          a.livesLost == 0,
    )
    ? 1
    : 0;

/// Every achievement, in gallery order.
final List<AchievementDef> kAchievements = [
  AchievementDef(
    'first_solve',
    'First Steps',
    'Solve your first puzzle.',
    BadgeKind.star,
    1,
    (s) => s.totalSolved,
    rewardHints: 1,
  ),
  AchievementDef(
    'island_hopper',
    'Island Hopper',
    'Solve a level on every island.',
    BadgeKind.island,
    GameId.values.length,
    _islandsVisited,
  ),
  AchievementDef(
    'path_finder',
    'Path Finder',
    'Solve 15 Thread levels.',
    BadgeKind.thread,
    15,
    (s) => _solvedLevels(s, GameId.thread),
    game: GameId.thread,
  ),
  AchievementDef(
    'swift_thread',
    'Swift Thread',
    'Solve a Hard Thread level under par.',
    BadgeKind.thread,
    1,
    (s) => _swift(s, GameId.thread),
    game: GameId.thread,
  ),
  AchievementDef(
    'patchwork_pro',
    'Patchwork Pro',
    'Solve 15 Quilt levels.',
    BadgeKind.quilt,
    15,
    (s) => _solvedLevels(s, GameId.quilt),
    game: GameId.quilt,
  ),
  AchievementDef(
    'swift_quilt',
    'Swift Stitcher',
    'Solve a Hard Quilt level under par.',
    BadgeKind.quilt,
    1,
    (s) => _swift(s, GameId.quilt),
    game: GameId.quilt,
  ),
  AchievementDef(
    'word_smith',
    'Word Smith',
    'Solve 15 Twist levels.',
    BadgeKind.twist,
    15,
    (s) => _solvedLevels(s, GameId.twist),
    game: GameId.twist,
  ),
  AchievementDef(
    'swift_twist',
    'Quick Reader',
    'Solve a Hard Twist level under par.',
    BadgeKind.twist,
    1,
    (s) => _swift(s, GameId.twist),
    game: GameId.twist,
  ),
  AchievementDef(
    'snow_counter',
    'Number Drifter',
    'Solve 15 Sudoku Six levels.',
    BadgeKind.sudoku,
    15,
    (s) => _solvedLevels(s, GameId.sudoku),
    game: GameId.sudoku,
  ),
  AchievementDef(
    'snow_perfect',
    'Snow Perfect',
    'Earn three stars on 10 Sudoku Six levels.',
    BadgeKind.sudoku,
    10,
    (s) => _threeStarLevels(s, GameId.sudoku),
    game: GameId.sudoku,
  ),
  AchievementDef(
    'clue_hunter',
    'Clue Hunter',
    'Solve 15 Sleuth levels.',
    BadgeKind.sleuth,
    15,
    (s) => _solvedLevels(s, GameId.sleuth),
    game: GameId.sleuth,
  ),
  AchievementDef(
    'swift_sleuth',
    'Quick Detective',
    'Solve a Hard Sleuth level under par.',
    BadgeKind.sleuth,
    1,
    (s) => _swift(s, GameId.sleuth),
    game: GameId.sleuth,
  ),
  AchievementDef(
    'bridge_builder',
    'Bridge Builder',
    'Solve 15 Bridges levels.',
    BadgeKind.bridges,
    15,
    (s) => _solvedLevels(s, GameId.bridges),
    game: GameId.bridges,
  ),
  AchievementDef(
    'swift_bridges',
    'Fast Crossing',
    'Solve a Hard Bridges level under par.',
    BadgeKind.bridges,
    1,
    (s) => _swift(s, GameId.bridges),
    game: GameId.bridges,
  ),
  AchievementDef(
    'clean_sweep',
    'Clean Sweep',
    'Solve 10 puzzles in a row without a hint.',
    BadgeKind.hint,
    10,
    _longestNoHintRun,
  ),
  AchievementDef(
    'week_streak',
    'Week Streak',
    'Play seven days in a row.',
    BadgeKind.streak,
    7,
    StreakRules.best,
  ),
  AchievementDef(
    'month_streak',
    'Month Streak',
    'Play thirty days in a row.',
    BadgeKind.streak,
    30,
    StreakRules.best,
    rewardHints: 5,
  ),
  AchievementDef(
    'daily_devotee',
    'Daily Devotee',
    'Solve 10 daily puzzles.',
    BadgeKind.sun,
    10,
    (s) => s.daily.length,
  ),
  AchievementDef(
    'early_bird',
    'Early Bird',
    'Solve a daily puzzle before 8 AM.',
    BadgeKind.sun,
    1,
    (s) => _hourSolve(s, (h) => h >= 4 && h < 8, dailyOnly: true),
  ),
  AchievementDef(
    'night_owl',
    'Night Owl',
    'Solve a puzzle between 10 PM and 4 AM.',
    BadgeKind.moon,
    1,
    (s) => _hourSolve(s, (h) => h >= 22 || h < 4),
  ),
  AchievementDef(
    'steady_hand',
    'Steady Hand',
    'Solve a Hard level without losing a life.',
    BadgeKind.heart,
    1,
    _steady,
  ),
  AchievementDef(
    'star_collector',
    'Star Collector',
    'Earn three stars on 50 levels.',
    BadgeKind.star,
    50,
    _threeStarLevels,
    rewardHints: 4,
  ),
  AchievementDef(
    'summit',
    'Summit',
    'Reach Expert on any island.',
    BadgeKind.crown,
    1,
    _reachedExpert,
    rewardHints: 4,
  ),
  AchievementDef(
    'century',
    'Century',
    'Solve 100 puzzles.',
    BadgeKind.star,
    100,
    (s) => s.totalSolved,
    rewardHints: 5,
  ),
  AchievementDef(
    'island_master',
    'Island Master',
    'Solve all 60 levels on one island.',
    BadgeKind.crown,
    Levels.perIsland,
    _bestIsland,
    rewardHints: 10,
  ),
];

abstract final class Achievements {
  static List<AchievementState> states(SaveData s) => [
    for (final d in kAchievements)
      AchievementState(d, min(d.target, d.measure(s)), s.achievements[d.id]),
  ];

  /// Achievements reached in [s] that aren't recorded as unlocked yet.
  static List<AchievementDef> newlyReached(SaveData s) => [
    for (final d in kAchievements)
      if (!s.achievements.containsKey(d.id) && d.measure(s) >= d.target) d,
  ];
}
