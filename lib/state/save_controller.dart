// The single source of truth for the save game, as a Riverpod Notifier.
//
// Why: every screen watches slices of one immutable SaveData, so a solve on the
// game screen instantly updates Home, the island map and Insights. Writes are
// debounced and flushed on pause so a kill never loses more than a moment.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/save_store.dart';
import '../domain/achievements.dart';
import '../domain/game_id.dart';
import '../domain/level_config.dart';
import '../domain/rules.dart';
import '../domain/save_data.dart';
import '../domain/tier.dart';

/// Overridden in bootstrap with the opened store.
final saveStoreProvider = Provider<SaveStore>((ref) => throw UnimplementedError('saveStoreProvider'));

/// Overridden in bootstrap with the loaded (or fresh) save.
final initialSaveProvider = Provider<SaveData>((ref) => throw UnimplementedError('initialSaveProvider'));

/// Injectable clock (tests use a fixed time).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// What happened when a level was solved — drives the celebration screen.
class LevelOutcome {
  const LevelOutcome({
    required this.spec,
    required this.stars,
    required this.seconds,
    required this.hints,
    required this.livesLost,
    required this.xp,
    required this.firstSolve,
    required this.previousBest,
    required this.chestHints,
    required this.tierCleared,
    required this.newAchievements,
    required this.relaxed,
  });
  final LevelSpec spec;
  final int stars, seconds, hints, livesLost, xp;
  final bool firstSolve;
  final int? previousBest;

  /// Hints paid out by a tier chest (0 when none).
  final int chestHints;

  /// Set when this solve finished a tier (and opened the next).
  final Tier? tierCleared;
  final List<AchievementDef> newAchievements;
  final bool relaxed;

  bool get newBest => previousBest != null && seconds < previousBest!;
}

class SaveController extends Notifier<SaveData> {
  Timer? _debounce;

  @override
  SaveData build() {
    ref.onDispose(() => _debounce?.cancel());
    return ref.read(initialSaveProvider);
  }

  DateTime get _now => ref.read(clockProvider)();
  SaveStore get _store => ref.read(saveStoreProvider);

  void _set(SaveData next) {
    state = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes the current state now (called on app pause and after big changes).
  Future<void> flush() {
    _debounce?.cancel();
    return _store.write(state);
  }

  // ---------- profile, settings, tips ----------

  void completeOnboarding({required String name, required int badge, required GameId firstGame, required bool playedBefore, required bool reminder}) {
    final games = Map<GameId, GameProgress>.of(state.games);
    if (playedBefore) {
      for (final g in GameId.values) {
        games[g] = (games[g] ?? const GameProgress()).copyWith(startLevel: Tier.medium.firstLevel);
      }
    }
    _set(state.copyWith(
      profile: state.profile.copyWith(name: name.trim(), badge: badge, onboarded: true, firstGame: firstGame, createdAt: _now.millisecondsSinceEpoch),
      settings: state.settings.copyWith(dailyReminder: reminder),
      games: games,
    ));
  }

  void updateProfile({String? name, int? badge}) => _set(state.copyWith(profile: state.profile.copyWith(name: name?.trim(), badge: badge)));

  void updateSettings(AppSettings Function(AppSettings s) change) => _set(state.copyWith(settings: change(state.settings)));

  void markTipSeen(String id) {
    if (state.seenTips.contains(id)) return;
    _set(state.copyWith(seenTips: {...state.seenTips, id}));
  }

  /// Starts a new app session (interstitial pacing skips the very first one).
  void countSession() => _set(state.copyWith(ads: state.ads.copyWith(sessions: state.ads.sessions + 1)));

  // ---------- lives & hints ----------

  /// Lives/hints as of now (refills applied), without writing.
  Economy get economyNow => EconomyRules.normalise(state.economy, _now);

  /// Persists refills and the daily free hints (on launch, resume and before play).
  void normaliseEconomy() {
    final n = economyNow;
    if (n.lives != state.economy.lives || n.hints != state.economy.hints || n.hintDay != state.economy.hintDay || n.livesStampMs != state.economy.livesStampMs) {
      _set(state.copyWith(economy: n));
    }
  }

  /// Takes one life (clock ran out). Returns the lives left.
  int loseLife() {
    final e = EconomyRules.loseLife(state.economy, _now);
    _set(state.copyWith(economy: e));
    return e.lives;
  }

  void addLife() => _set(state.copyWith(economy: EconomyRules.addLife(state.economy, _now)));

  void addHints(int n) => _set(state.copyWith(economy: EconomyRules.addHints(economyNow, n)));

  /// Spends a hint; false when none are left.
  bool spendHint() {
    final e = economyNow;
    if (e.hints <= 0) return false;
    _set(state.copyWith(economy: EconomyRules.spendHint(e)));
    return true;
  }

  // ---------- results ----------

  List<Attempt> _withAttempt(Attempt a) {
    final list = [...state.attempts, a];
    return list.length > SaveData.maxAttempts ? list.sublist(list.length - SaveData.maxAttempts) : list;
  }

  /// Records a solved level (or daily) and returns everything the celebration needs.
  LevelOutcome recordSolve(LevelSpec spec, {required int seconds, required int hints, required int livesLost}) {
    final now = _now;
    final relaxed = state.settings.relaxed;
    final stars = ScoreRules.stars(relaxed: relaxed, seconds: seconds, par: spec.parSeconds, hints: hints);
    var next = state;
    var firstSolve = true;
    int? previousBest;
    var chestHints = 0;
    Tier? tierCleared;

    if (spec.isDaily) {
      final key = spec.dayKey ?? dayKey(now);
      final prev = next.daily[key];
      firstSolve = prev == null;
      previousBest = prev?.seconds;
      final rec = DailyRecord(game: spec.game, stars: prev == null || stars > prev.stars ? stars : prev.stars, seconds: prev == null || seconds < prev.seconds ? seconds : prev.seconds);
      next = next.copyWith(daily: {...next.daily, key: rec});
    } else {
      final prog = next.progress(spec.game);
      final prev = prog.levels[spec.level];
      firstSolve = prev == null;
      previousBest = prev?.bestSeconds;
      final rec = LevelRecord(stars: stars, bestSeconds: seconds, noHint: hints == 0, solvedAt: now.millisecondsSinceEpoch);
      var updated = prog.copyWith(levels: {...prog.levels, spec.level: prev == null ? rec : prev.merge(rec)});
      if (Levels.isGate(spec.level) && !prog.chestsOpened.contains(spec.level)) {
        chestHints = ScoreRules.chestHints(spec.tier);
        updated = updated.copyWith(chestsOpened: {...prog.chestsOpened, spec.level});
        tierCleared = spec.tier;
      }
      next = next.copyWith(games: {...next.games, spec.game: updated});
    }

    final xp = ScoreRules.xp(stars: stars, tier: spec.tier, daily: spec.isDaily, firstSolve: firstSolve);
    next = next.copyWith(
      xp: next.xp + xp,
      attempts: _withAttempt(Attempt(
        game: spec.game,
        level: spec.level,
        at: now.millisecondsSinceEpoch,
        solved: true,
        seconds: seconds,
        hints: hints,
        livesLost: livesLost,
        stars: stars,
        daily: spec.isDaily,
      )),
      ads: next.ads.copyWith(solvedSinceAd: next.ads.solvedSinceAd + 1),
    );
    if (chestHints > 0) next = next.copyWith(economy: EconomyRules.addHints(EconomyRules.normalise(next.economy, now), chestHints));

    final reached = Achievements.newlyReached(next);
    if (reached.isNotEmpty) {
      final rewards = reached.fold(0, (n, d) => n + d.rewardHints);
      next = next.copyWith(
        achievements: {...next.achievements, for (final d in reached) d.id: now.millisecondsSinceEpoch},
        economy: EconomyRules.addHints(EconomyRules.normalise(next.economy, now), rewards),
      );
    }
    _set(next);
    unawaited(flush());
    return LevelOutcome(
      spec: spec,
      stars: stars,
      seconds: seconds,
      hints: hints,
      livesLost: livesLost,
      xp: xp,
      firstSolve: firstSolve,
      previousBest: previousBest,
      chestHints: chestHints,
      tierCleared: tierCleared,
      newAchievements: reached,
      relaxed: relaxed,
    );
  }

  /// Records an attempt that ended without a solve (out of lives or quit after playing).
  void recordFailure(LevelSpec spec, {required int seconds, required int hints, required int livesLost}) {
    if (seconds <= 0 && hints == 0 && livesLost == 0) return;
    _set(state.copyWith(
      attempts: _withAttempt(Attempt(
        game: spec.game,
        level: spec.level,
        at: _now.millisecondsSinceEpoch,
        solved: false,
        seconds: seconds,
        hints: hints,
        livesLost: livesLost,
        daily: spec.isDaily,
      )),
    ));
  }

  // ---------- ads pacing ----------

  /// Interstitial rule: after a solve, at most once every 3 solves and 4 minutes,
  /// never in the first session.
  bool interstitialDue() {
    final a = state.ads;
    if (a.sessions <= 1) return false;
    if (a.solvedSinceAd < 3) return false;
    return _now.millisecondsSinceEpoch - a.lastAdMs >= 4 * 60 * 1000;
  }

  void markInterstitialShown() => _set(state.copyWith(ads: state.ads.copyWith(solvedSinceAd: 0, lastAdMs: _now.millisecondsSinceEpoch)));

  // ---------- restore ----------

  /// Replaces everything with a restored backup (keeps this phone's ad pacing).
  Future<void> replaceAll(SaveData restored) async {
    _set(restored.copyWith(ads: state.ads, profile: restored.profile.copyWith(onboarded: true)));
    await flush();
  }

  /// Wipes progress but keeps settings and the profile (Settings › Reset all progress).
  Future<void> resetProgress() async {
    _set(SaveData(profile: state.profile, settings: state.settings, ads: state.ads, seenTips: state.seenTips));
    await flush();
  }
}

final saveProvider = NotifierProvider<SaveController, SaveData>(SaveController.new);

final settingsProvider = Provider<AppSettings>((ref) => ref.watch(saveProvider.select((s) => s.settings)));

/// Emits every second while watched — drives countdowns (lives refill, daily reset).
final secondTickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock());
});

/// Lives and hints right now, refreshed every second where watched.
final economyProvider = Provider.autoDispose<Economy>((ref) {
  ref.watch(secondTickerProvider);
  final e = ref.watch(saveProvider.select((s) => s.economy));
  return EconomyRules.normalise(e, ref.read(clockProvider)());
});
