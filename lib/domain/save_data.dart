// The whole save game as one immutable value with JSON (de)serialisation.
//
// Why one document: the game is offline and small (levels, stars, a capped
// attempt log, settings). One JSON file is easy to write atomically, to back up
// as a single .mindisles file and to restore — nothing gets left out.

import 'game_id.dart';
import 'tier.dart';

T _v<T>(Map<String, Object?> j, String k, T d) {
  final v = j[k];
  if (v is T) return v;
  if (T == double && v is int) return v.toDouble() as T;
  return d;
}

/// Day / Night / follow the phone.
enum ThemeChoice { day, night, system }

/// Player profile (no account — lives only on this phone).
class Profile {
  const Profile({this.name = '', this.badge = 0, this.onboarded = false, this.firstGame = GameId.thread, this.createdAt = 0});
  final String name;

  /// Index into the badge list (compass, shell, palm, crystal, snowflake, star).
  final int badge;
  final bool onboarded;
  final GameId firstGame;
  final int createdAt;

  Profile copyWith({String? name, int? badge, bool? onboarded, GameId? firstGame, int? createdAt}) => Profile(
        name: name ?? this.name,
        badge: badge ?? this.badge,
        onboarded: onboarded ?? this.onboarded,
        firstGame: firstGame ?? this.firstGame,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toJson() => {'name': name, 'badge': badge, 'onboarded': onboarded, 'firstGame': firstGame.key, 'createdAt': createdAt};
  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        name: _v(j, 'name', ''),
        badge: _v(j, 'badge', 0),
        onboarded: _v(j, 'onboarded', false),
        firstGame: GameId.fromKey(_v(j, 'firstGame', 'thread')),
        createdAt: _v(j, 'createdAt', 0),
      );
}

/// Everything on the Settings screen.
class AppSettings {
  const AppSettings({
    this.theme = ThemeChoice.system,
    this.colourBlind = false,
    this.largeNumbers = false,
    this.relaxed = false,
    this.showClock = true,
    this.markMistakes = true,
    this.confirmHint = false,
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.dailyReminder = true,
    this.reminderMinutes = 20 * 60,
    this.livesAlert = true,
    this.autoBackup = true,
    this.backupWeekly = false,
  });

  final ThemeChoice theme;
  final bool colourBlind, largeNumbers, relaxed, showClock, markMistakes, confirmHint;
  final bool sound, haptics, reduceMotion;
  final bool dailyReminder;

  /// Minutes after midnight for the daily reminder.
  final int reminderMinutes;
  final bool livesAlert;
  final bool autoBackup;
  final bool backupWeekly;

  AppSettings copyWith({
    ThemeChoice? theme,
    bool? colourBlind,
    bool? largeNumbers,
    bool? relaxed,
    bool? showClock,
    bool? markMistakes,
    bool? confirmHint,
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    bool? dailyReminder,
    int? reminderMinutes,
    bool? livesAlert,
    bool? autoBackup,
    bool? backupWeekly,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        colourBlind: colourBlind ?? this.colourBlind,
        largeNumbers: largeNumbers ?? this.largeNumbers,
        relaxed: relaxed ?? this.relaxed,
        showClock: showClock ?? this.showClock,
        markMistakes: markMistakes ?? this.markMistakes,
        confirmHint: confirmHint ?? this.confirmHint,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        livesAlert: livesAlert ?? this.livesAlert,
        autoBackup: autoBackup ?? this.autoBackup,
        backupWeekly: backupWeekly ?? this.backupWeekly,
      );

  Map<String, Object?> toJson() => {
        'theme': theme.name,
        'colourBlind': colourBlind,
        'largeNumbers': largeNumbers,
        'relaxed': relaxed,
        'showClock': showClock,
        'markMistakes': markMistakes,
        'confirmHint': confirmHint,
        'sound': sound,
        'haptics': haptics,
        'reduceMotion': reduceMotion,
        'dailyReminder': dailyReminder,
        'reminderMinutes': reminderMinutes,
        'livesAlert': livesAlert,
        'autoBackup': autoBackup,
        'backupWeekly': backupWeekly,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    return AppSettings(
      theme: ThemeChoice.values.firstWhere((t) => t.name == j['theme'], orElse: () => d.theme),
      colourBlind: _v(j, 'colourBlind', d.colourBlind),
      largeNumbers: _v(j, 'largeNumbers', d.largeNumbers),
      relaxed: _v(j, 'relaxed', d.relaxed),
      showClock: _v(j, 'showClock', d.showClock),
      markMistakes: _v(j, 'markMistakes', d.markMistakes),
      confirmHint: _v(j, 'confirmHint', d.confirmHint),
      sound: _v(j, 'sound', d.sound),
      haptics: _v(j, 'haptics', d.haptics),
      reduceMotion: _v(j, 'reduceMotion', d.reduceMotion),
      dailyReminder: _v(j, 'dailyReminder', d.dailyReminder),
      reminderMinutes: _v(j, 'reminderMinutes', d.reminderMinutes),
      livesAlert: _v(j, 'livesAlert', d.livesAlert),
      autoBackup: _v(j, 'autoBackup', d.autoBackup),
      backupWeekly: _v(j, 'backupWeekly', d.backupWeekly),
    );
  }
}

/// Lives and hints. Lives refill over time; free hints top up once a day.
class Economy {
  const Economy({this.lives = Economy.maxLives, this.livesStampMs = 0, this.hints = Economy.dailyFreeHints, this.hintDay = ''});

  static const maxLives = 3;
  static const refillMinutes = 20;
  static const dailyFreeHints = 3;
  static const maxHints = 99;

  /// Lives as last stored; the live count adds refills since [livesStampMs].
  final int lives;

  /// When [lives] was last written (ms since epoch) — the refill clock starts here.
  final int livesStampMs;
  final int hints;

  /// yyyy-MM-dd of the last free-hint top-up.
  final String hintDay;

  Economy copyWith({int? lives, int? livesStampMs, int? hints, String? hintDay}) => Economy(
        lives: lives ?? this.lives,
        livesStampMs: livesStampMs ?? this.livesStampMs,
        hints: hints ?? this.hints,
        hintDay: hintDay ?? this.hintDay,
      );

  Map<String, Object?> toJson() => {'lives': lives, 'livesStampMs': livesStampMs, 'hints': hints, 'hintDay': hintDay};
  factory Economy.fromJson(Map<String, Object?> j) => Economy(
        lives: _v(j, 'lives', maxLives),
        livesStampMs: _v(j, 'livesStampMs', 0),
        hints: _v(j, 'hints', dailyFreeHints),
        hintDay: _v(j, 'hintDay', ''),
      );
}

/// Best result on one level.
class LevelRecord {
  const LevelRecord({required this.stars, required this.bestSeconds, required this.noHint, required this.solvedAt, this.plays = 1});
  final int stars;
  final int bestSeconds;
  final bool noHint;
  final int solvedAt;
  final int plays;

  /// Keeps the best of both results (stars, time, no-hint) and counts the play.
  LevelRecord merge(LevelRecord other) => LevelRecord(
        stars: other.stars > stars ? other.stars : stars,
        bestSeconds: other.bestSeconds < bestSeconds ? other.bestSeconds : bestSeconds,
        noHint: noHint || other.noHint,
        solvedAt: solvedAt,
        plays: plays + 1,
      );

  Map<String, Object?> toJson() => {'s': stars, 't': bestSeconds, 'n': noHint, 'at': solvedAt, 'p': plays};
  factory LevelRecord.fromJson(Map<String, Object?> j) => LevelRecord(
        stars: _v(j, 's', 1),
        bestSeconds: _v(j, 't', 0),
        noHint: _v(j, 'n', false),
        solvedAt: _v(j, 'at', 0),
        plays: _v(j, 'p', 1),
      );
}

/// Progress on one island.
class GameProgress {
  const GameProgress({this.levels = const {}, this.startLevel = 1, this.chestsOpened = const {}});

  /// Solved levels only.
  final Map<int, LevelRecord> levels;

  /// Levels below this are open without being solved ("I've played before").
  final int startLevel;

  /// Gate levels whose chest reward was already paid out.
  final Set<int> chestsOpened;

  int get highestSolved => levels.keys.fold(0, (a, b) => b > a ? b : a);

  /// The frontier: first unsolved level from [startLevel] on. The island map centres
  /// on it and "Continue" opens it. Levels after it are locked.
  int get current {
    for (var l = startLevel; l <= Levels.perIsland; l++) {
      if (!levels.containsKey(l)) return l;
    }
    return Levels.perIsland;
  }

  /// Whether [level] can be played (solved levels can always be replayed).
  bool isPlayable(int level) => level <= current || levels.containsKey(level);

  bool get completed => levels.length >= Levels.perIsland - (startLevel - 1);
  int get stars => levels.values.fold(0, (a, r) => a + r.stars);

  GameProgress copyWith({Map<int, LevelRecord>? levels, int? startLevel, Set<int>? chestsOpened}) => GameProgress(
        levels: levels ?? this.levels,
        startLevel: startLevel ?? this.startLevel,
        chestsOpened: chestsOpened ?? this.chestsOpened,
      );

  Map<String, Object?> toJson() => {
        'levels': {for (final e in levels.entries) '${e.key}': e.value.toJson()},
        'startLevel': startLevel,
        'chests': chestsOpened.toList()..sort(),
      };
  factory GameProgress.fromJson(Map<String, Object?> j) {
    final lv = j['levels'] is Map ? (j['levels'] as Map).cast<String, Object?>() : const <String, Object?>{};
    return GameProgress(
      levels: {for (final e in lv.entries) if (int.tryParse(e.key) != null && e.value is Map) int.parse(e.key): LevelRecord.fromJson((e.value as Map).cast<String, Object?>())},
      startLevel: _v(j, 'startLevel', 1),
      chestsOpened: (j['chests'] is List ? j['chests'] as List : const []).whereType<int>().toSet(),
    );
  }
}

/// One finished attempt (solved or not) — the raw data behind Insights.
class Attempt {
  const Attempt({
    required this.game,
    required this.level,
    required this.at,
    required this.solved,
    required this.seconds,
    this.hints = 0,
    this.livesLost = 0,
    this.stars = 0,
    this.daily = false,
  });
  final GameId game;
  final int level;

  /// Finish time (ms since epoch, UTC instant).
  final int at;
  final bool solved;
  final int seconds;
  final int hints;
  final int livesLost;
  final int stars;
  final bool daily;

  Map<String, Object?> toJson() => {'g': game.key, 'l': level, 'at': at, 'ok': solved, 't': seconds, 'h': hints, 'x': livesLost, 's': stars, if (daily) 'd': true};
  factory Attempt.fromJson(Map<String, Object?> j) => Attempt(
        game: GameId.fromKey(_v(j, 'g', 'thread')),
        level: _v(j, 'l', 0),
        at: _v(j, 'at', 0),
        solved: _v(j, 'ok', false),
        seconds: _v(j, 't', 0),
        hints: _v(j, 'h', 0),
        livesLost: _v(j, 'x', 0),
        stars: _v(j, 's', 0),
        daily: _v(j, 'd', false),
      );
}

/// Daily-puzzle result for one day.
class DailyRecord {
  const DailyRecord({required this.game, required this.stars, required this.seconds});
  final GameId game;
  final int stars;
  final int seconds;
  Map<String, Object?> toJson() => {'g': game.key, 's': stars, 't': seconds};
  factory DailyRecord.fromJson(Map<String, Object?> j) => DailyRecord(game: GameId.fromKey(_v(j, 'g', 'thread')), stars: _v(j, 's', 1), seconds: _v(j, 't', 0));
}

/// Interstitial pacing state (persisted so the cap survives restarts).
class AdPacing {
  const AdPacing({this.solvedSinceAd = 0, this.lastAdMs = 0, this.sessions = 0});
  final int solvedSinceAd;
  final int lastAdMs;

  /// App launches so far — no interstitials in the very first session.
  final int sessions;
  AdPacing copyWith({int? solvedSinceAd, int? lastAdMs, int? sessions}) =>
      AdPacing(solvedSinceAd: solvedSinceAd ?? this.solvedSinceAd, lastAdMs: lastAdMs ?? this.lastAdMs, sessions: sessions ?? this.sessions);
  Map<String, Object?> toJson() => {'solved': solvedSinceAd, 'last': lastAdMs, 'sessions': sessions};
  factory AdPacing.fromJson(Map<String, Object?> j) => AdPacing(solvedSinceAd: _v(j, 'solved', 0), lastAdMs: _v(j, 'last', 0), sessions: _v(j, 'sessions', 0));
}

/// The whole save game.
class SaveData {
  const SaveData({
    this.profile = const Profile(),
    this.settings = const AppSettings(),
    this.economy = const Economy(),
    this.games = const {},
    this.attempts = const [],
    this.daily = const {},
    this.achievements = const {},
    this.xp = 0,
    this.seenTips = const {},
    this.ads = const AdPacing(),
  });

  static const maxAttempts = 3000;

  final Profile profile;
  final AppSettings settings;
  final Economy economy;
  final Map<GameId, GameProgress> games;
  final List<Attempt> attempts;

  /// yyyy-MM-dd → result of that day's daily puzzle.
  final Map<String, DailyRecord> daily;

  /// Achievement id → unlock time (ms).
  final Map<String, int> achievements;
  final int xp;

  /// One-time tips already shown (coach marks, how-to-play per game).
  final Set<String> seenTips;
  final AdPacing ads;

  GameProgress progress(GameId g) => games[g] ?? const GameProgress();
  int get totalStars => games.values.fold(0, (a, g) => a + g.stars);
  int get totalSolved => games.values.fold(0, (a, g) => a + g.levels.length) + daily.length;

  /// Player level from XP: 200 XP per level, starting at level 1.
  int get playerLevel => xp ~/ 200 + 1;
  int get xpIntoLevel => xp % 200;

  SaveData copyWith({
    Profile? profile,
    AppSettings? settings,
    Economy? economy,
    Map<GameId, GameProgress>? games,
    List<Attempt>? attempts,
    Map<String, DailyRecord>? daily,
    Map<String, int>? achievements,
    int? xp,
    Set<String>? seenTips,
    AdPacing? ads,
  }) =>
      SaveData(
        profile: profile ?? this.profile,
        settings: settings ?? this.settings,
        economy: economy ?? this.economy,
        games: games ?? this.games,
        attempts: attempts ?? this.attempts,
        daily: daily ?? this.daily,
        achievements: achievements ?? this.achievements,
        xp: xp ?? this.xp,
        seenTips: seenTips ?? this.seenTips,
        ads: ads ?? this.ads,
      );

  Map<String, Object?> toJson() => {
        'profile': profile.toJson(),
        'settings': settings.toJson(),
        'economy': economy.toJson(),
        'games': {for (final e in games.entries) e.key.key: e.value.toJson()},
        'attempts': [for (final a in attempts) a.toJson()],
        'daily': {for (final e in daily.entries) e.key: e.value.toJson()},
        'achievements': achievements,
        'xp': xp,
        'seenTips': seenTips.toList()..sort(),
        'ads': ads.toJson(),
      };

  factory SaveData.fromJson(Map<String, Object?> j) {
    Map<String, Object?> m(String k) => j[k] is Map ? (j[k] as Map).cast<String, Object?>() : const {};
    Map<String, Object?> asMap(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
    return SaveData(
      profile: Profile.fromJson(m('profile')),
      settings: AppSettings.fromJson(m('settings')),
      economy: Economy.fromJson(m('economy')),
      games: {for (final e in m('games').entries) if (GameId.values.any((g) => g.key == e.key)) GameId.fromKey(e.key): GameProgress.fromJson(asMap(e.value))},
      attempts: [for (final a in j['attempts'] is List ? j['attempts'] as List : const []) if (a is Map) Attempt.fromJson(asMap(a))],
      daily: {for (final e in m('daily').entries) if (e.value is Map) e.key: DailyRecord.fromJson(asMap(e.value))},
      achievements: {for (final e in m('achievements').entries) if (e.value is int) e.key: e.value as int},
      xp: _v(j, 'xp', 0),
      seenTips: (j['seenTips'] is List ? j['seenTips'] as List : const []).whereType<String>().toSet(),
      ads: AdPacing.fromJson(m('ads')),
    );
  }
}
