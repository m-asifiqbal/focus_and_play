import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/storage/save_store.dart';
import 'package:focus_and_play_mindgame/domain/achievements.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/insights.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/domain/tier.dart';
import 'package:focus_and_play_mindgame/state/save_controller.dart';

void main() {
  late Directory dir;
  late DateTime now;
  late ProviderContainer c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mi_ctl');
    now = DateTime(2026, 10, 24, 21, 0);
    c = ProviderContainer(overrides: [
      saveStoreProvider.overrideWithValue(SaveStore(dir)),
      initialSaveProvider.overrideWithValue(const SaveData()),
      clockProvider.overrideWithValue(() => now),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await dir.delete(recursive: true);
  });

  SaveController ctl() => c.read(saveProvider.notifier);

  test('a solve records stars, XP, the attempt and the first-solve achievement', () {
    final spec = LevelConfig.forLevel(GameId.thread, 1);
    final o = ctl().recordSolve(spec, seconds: spec.parSeconds - 1, hints: 0, livesLost: 0);
    expect(o.stars, 3);
    expect(o.firstSolve, isTrue);
    expect(o.xp, greaterThan(0));
    final s = c.read(saveProvider);
    expect(s.progress(GameId.thread).levels[1]!.stars, 3);
    expect(s.progress(GameId.thread).current, 2);
    expect(s.attempts.single.solved, isTrue);
    expect(o.newAchievements.map((a) => a.id), contains('first_solve'));
    expect(s.achievements.containsKey('first_solve'), isTrue);
  });

  test('replaying keeps the best result and counts the play', () {
    final spec = LevelConfig.forLevel(GameId.quilt, 1);
    ctl().recordSolve(spec, seconds: 30, hints: 0, livesLost: 0);
    final o = ctl().recordSolve(spec, seconds: 200, hints: 2, livesLost: 1);
    expect(o.firstSolve, isFalse);
    final r = c.read(saveProvider).progress(GameId.quilt).levels[1]!;
    expect(r.bestSeconds, 30);
    expect(r.stars, 3);
    expect(r.plays, 2);
  });

  test('finishing a tier gate opens the chest once and pays hints', () {
    final before = ctl().economyNow.hints;
    final gate = LevelConfig.forLevel(GameId.sudoku, Tier.easy.lastLevel);
    final o = ctl().recordSolve(gate, seconds: 50, hints: 0, livesLost: 0);
    expect(o.tierCleared, Tier.easy);
    expect(o.chestHints, greaterThan(0));
    expect(ctl().economyNow.hints, greaterThanOrEqualTo(before + o.chestHints));
    final again = ctl().recordSolve(gate, seconds: 40, hints: 0, livesLost: 0);
    expect(again.chestHints, 0);
    expect(again.tierCleared, isNull);
  });

  test('the daily puzzle is stored per day', () {
    final spec = LevelConfig.daily(now);
    ctl().recordSolve(spec, seconds: 80, hints: 1, livesLost: 0);
    expect(c.read(saveProvider).daily[spec.dayKey]!.seconds, 80);
  });

  test('lives, hints and the interstitial pacing', () {
    expect(ctl().loseLife(), 2);
    expect(ctl().spendHint(), isTrue);
    ctl().countSession();
    expect(ctl().interstitialDue(), isFalse, reason: 'never in the first session');
    ctl().countSession();
    for (var l = 1; l <= 3; l++) {
      ctl().recordSolve(LevelConfig.forLevel(GameId.twist, l), seconds: 30, hints: 0, livesLost: 0);
    }
    expect(ctl().interstitialDue(), isTrue);
    ctl().markInterstitialShown();
    expect(ctl().interstitialDue(), isFalse);
  });

  test('"I\'ve played before" opens Medium on every island', () {
    ctl().completeOnboarding(name: ' Sam ', badge: 2, firstGame: GameId.quilt, playedBefore: true, reminder: false);
    final s = c.read(saveProvider);
    expect(s.profile.name, 'Sam');
    for (final g in GameId.values) {
      expect(s.progress(g).current, Tier.medium.firstLevel);
    }
  });

  test('restore replaces progress; reset keeps profile and settings', () async {
    ctl().updateProfile(name: 'Ana');
    ctl().recordSolve(LevelConfig.forLevel(GameId.thread, 1), seconds: 30, hints: 0, livesLost: 0);
    await ctl().resetProgress();
    expect(c.read(saveProvider).profile.name, 'Ana');
    expect(c.read(saveProvider).totalSolved, 0);
    await ctl().replaceAll(const SaveData(xp: 999));
    expect(c.read(saveProvider).xp, 999);
    expect(c.read(saveProvider).profile.onboarded, isTrue);
  });

  test('insights and achievement progress reflect solves', () {
    for (var l = 1; l <= 5; l++) {
      ctl().recordSolve(LevelConfig.forLevel(GameId.thread, l), seconds: 20 + l, hints: 0, livesLost: 0);
    }
    final s = c.read(saveProvider);
    final o = InsightsCalc.overview(s, InsightPeriod.week, now);
    expect(o.solved, 5);
    expect(o.lastSevenDays.last, 5);
    final g = InsightsCalc.game(s, GameId.thread, InsightPeriod.all, now);
    expect(g.bestSeconds, 21);
    expect(g.trend.length, 5);
    expect(g.heat.last, 5);
    final pathFinder = Achievements.states(s).firstWhere((a) => a.def.id == 'path_finder');
    expect(pathFinder.current, 5);
    expect(pathFinder.unlocked, isFalse);
  });
}
