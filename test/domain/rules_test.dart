import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/rules.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/domain/tier.dart';

void main() {
  final t0 = DateTime(2026, 10, 24, 20, 0);

  group('lives', () {
    test('losing from full starts the refill clock; one life comes back every 20 minutes', () {
      var e = EconomyRules.normalise(const Economy(), t0);
      e = EconomyRules.loseLife(e, t0);
      expect(e.lives, 2);
      expect(EconomyRules.nextLifeIn(e, t0.add(const Duration(minutes: 5))), const Duration(minutes: 15));
      expect(EconomyRules.normalise(e, t0.add(const Duration(minutes: 19))).lives, 2);
      expect(EconomyRules.normalise(e, t0.add(const Duration(minutes: 20))).lives, 3);
    });

    test('several lives refill one by one and never exceed three', () {
      var e = EconomyRules.normalise(const Economy(), t0);
      for (var i = 0; i < 3; i++) {
        e = EconomyRules.loseLife(e, t0);
      }
      expect(e.lives, 0);
      expect(EconomyRules.normalise(e, t0.add(const Duration(minutes: 41))).lives, 2);
      expect(EconomyRules.fullAt(e, t0), t0.add(const Duration(minutes: 60)));
      expect(EconomyRules.normalise(e, t0.add(const Duration(days: 2))).lives, 3);
      expect(EconomyRules.loseLife(e, t0).lives, 0, reason: 'cannot go below zero');
    });

    test('a refill keeps the partial progress toward the next life', () {
      var e = EconomyRules.normalise(const Economy(), t0);
      e = EconomyRules.loseLife(e, t0);
      e = EconomyRules.loseLife(e, t0.add(const Duration(minutes: 10)));
      final later = EconomyRules.normalise(e, t0.add(const Duration(minutes: 25)));
      expect(later.lives, 2);
      expect(EconomyRules.nextLifeIn(later, t0.add(const Duration(minutes: 25))), const Duration(minutes: 15));
    });
  });

  group('hints', () {
    test('free hints top up to 3 once per day, extra hints are kept', () {
      var e = EconomyRules.normalise(const Economy(hints: 0, hintDay: '2026-10-23'), t0);
      expect(e.hints, Economy.dailyFreeHints);
      e = EconomyRules.spendHint(e);
      expect(EconomyRules.normalise(e, t0.add(const Duration(hours: 1))).hints, 2, reason: 'same day: no top-up');
      e = EconomyRules.addHints(e, 7);
      expect(EconomyRules.normalise(e, t0.add(const Duration(days: 1))).hints, 9, reason: 'more than 3: kept');
    });
  });

  group('stars and xp', () {
    test('one for solving, one for par, one for no hints; relaxed caps at one', () {
      expect(ScoreRules.stars(relaxed: false, seconds: 50, par: 60, hints: 0), 3);
      expect(ScoreRules.stars(relaxed: false, seconds: 70, par: 60, hints: 0), 2);
      expect(ScoreRules.stars(relaxed: false, seconds: 50, par: 60, hints: 1), 2);
      expect(ScoreRules.stars(relaxed: false, seconds: 70, par: 60, hints: 2), 1);
      expect(ScoreRules.stars(relaxed: true, seconds: 10, par: 60, hints: 0), 1);
    });

    test('replays give less XP than first solves; harder tiers give more', () {
      final first = ScoreRules.xp(stars: 3, tier: Tier.hard);
      expect(ScoreRules.xp(stars: 3, tier: Tier.hard, firstSolve: false), lessThan(first));
      expect(ScoreRules.xp(stars: 3, tier: Tier.easy), lessThan(first));
    });
  });

  group('streak', () {
    SaveData withSolves(List<DateTime> days) => SaveData(attempts: [
          for (final d in days) Attempt(game: GameId.thread, level: 1, at: d.millisecondsSinceEpoch, solved: true, seconds: 30),
        ]);

    test('counts consecutive days ending today or yesterday', () {
      final s = withSolves([t0, t0.subtract(const Duration(days: 1)), t0.subtract(const Duration(days: 2)), t0.subtract(const Duration(days: 4))]);
      expect(StreakRules.current(s, t0), 3);
      expect(StreakRules.current(s, t0.add(const Duration(days: 1))), 3, reason: "today not played yet: yesterday's streak still shows");
      expect(StreakRules.current(s, t0.add(const Duration(days: 2))), 0);
      expect(StreakRules.best(s), 3);
    });
  });
}
