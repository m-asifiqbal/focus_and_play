import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/core/storage/save_store.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/domain/save_data.dart';
import 'package:focus_and_play_mindgame/domain/tier.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku.dart';
import 'package:focus_and_play_mindgame/games/thread/thread.dart';
import 'package:focus_and_play_mindgame/games/twist/twist.dart';

SaveData sample() => SaveData(
      profile: const Profile(name: 'Sam', badge: 3, onboarded: true, firstGame: GameId.twist, createdAt: 1),
      settings: const AppSettings(theme: ThemeChoice.night, relaxed: true, reminderMinutes: 7 * 60 + 30),
      economy: const Economy(lives: 1, livesStampMs: 99, hints: 7, hintDay: '2026-10-24'),
      games: {
        GameId.thread: const GameProgress(levels: {1: LevelRecord(stars: 3, bestSeconds: 20, noHint: true, solvedAt: 5)}, chestsOpened: {15}),
        GameId.sudoku: const GameProgress(startLevel: 16),
      },
      attempts: const [Attempt(game: GameId.quilt, level: 4, at: 123, solved: false, seconds: 40, hints: 1, livesLost: 1)],
      daily: const {'2026-10-24': DailyRecord(game: GameId.twist, stars: 2, seconds: 77)},
      achievements: const {'first_solve': 55},
      xp: 420,
      seenTips: const {'coach', 'howto_thread'},
      ads: const AdPacing(solvedSinceAd: 2, lastAdMs: 9, sessions: 4),
    );

void main() {
  test('save data survives a JSON round trip (everything a backup must hold)', () {
    final a = sample();
    final b = SaveData.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>);
    expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
    expect(b.settings.theme, ThemeChoice.night);
    expect(b.progress(GameId.thread).levels[1]!.stars, 3);
    expect(b.progress(GameId.sudoku).current, 16);
  });

  test('missing or wrong fields fall back to defaults instead of crashing', () {
    final s = SaveData.fromJson({'profile': {'name': 3}, 'economy': 'oops', 'games': {'nope': {}}});
    expect(s.profile.name, '');
    expect(s.economy.lives, Economy.maxLives);
  });

  test('backup envelope encodes, decodes and rejects foreign files', () {
    final bytes = SaveStore.encodeBackup(sample(), DateTime(2026, 10, 24));
    final p = SaveStore.decodeBackup(bytes);
    expect(p.info.levels, 1);
    expect(p.info.stars, 3);
    expect(p.data.profile.name, 'Sam');
    expect(() => SaveStore.decodeBackup(utf8.encode('{"hello":1}')), throwsFormatException);
    expect(() => SaveStore.decodeBackup(utf8.encode('not json')), throwsFormatException);
  });

  test('store writes atomically, loads back, and keeps the newest 5 automatic backups', () async {
    final dir = await Directory.systemTemp.createTemp('mi_store');
    addTearDown(() => dir.delete(recursive: true));
    final store = SaveStore(dir);
    expect(await store.load(), isNull);
    await store.write(sample());
    expect((await store.load())!.xp, 420);
    for (var i = 0; i < 7; i++) {
      await store.writeLocalBackup(sample(), DateTime(2026, 10, 1 + i), automatic: true);
    }
    await store.writeLocalBackup(sample(), DateTime(2026, 9, 1));
    final list = await store.listBackups();
    expect(list.where((b) => b.automatic).length, 5);
    expect(list.where((b) => !b.automatic).length, 1);
    expect(list.first.createdAt, DateTime(2026, 10, 7));
  });

  test('a damaged save file falls back to the newest backup', () async {
    final dir = await Directory.systemTemp.createTemp('mi_store');
    addTearDown(() => dir.delete(recursive: true));
    final store = SaveStore(dir);
    await store.writeLocalBackup(sample(), DateTime(2026, 10, 2), automatic: true);
    await File('${dir.path}/save.json').writeAsString('{broken');
    expect((await store.load())!.profile.name, 'Sam');
  });

  test('progress frontier and playable levels', () {
    final p = GameProgress(levels: {for (var l = 1; l <= 5; l++) l: const LevelRecord(stars: 1, bestSeconds: 1, noHint: true, solvedAt: 0)});
    expect(p.current, 6);
    expect(p.isPlayable(6), isTrue);
    expect(p.isPlayable(7), isFalse);
    expect(p.isPlayable(3), isTrue);
    const skipped = GameProgress(startLevel: 16);
    expect(skipped.current, 16);
    expect(skipped.isPlayable(2), isTrue, reason: 'skipped Easy levels stay playable');
  });

  test('every level of every island generates a valid puzzle, deterministically', () {
    for (final g in GameId.values) {
      for (var level = 1; level <= Levels.perIsland; level++) {
        final spec = LevelConfig.forLevel(g, level);
        expect(spec.clockSeconds, greaterThan(spec.parSeconds));
        final p = generatePuzzle(spec);
        switch (p) {
          case ThreadPuzzle t:
            expect(ThreadRules.isSolved(t, t.solution), isTrue, reason: '$g $level');
          case QuiltPuzzle q:
            expect(QuiltRules.isSolved(q, q.solution), isTrue, reason: '$g $level');
          case TwistPuzzle w:
            expect(TwistRules.isSolved(w, {for (var i = 0; i < w.words.length; i++) i}), isTrue, reason: '$g $level');
          case SudokuPuzzle s:
            expect(SudokuRules.isSolved(s, s.solution), isTrue, reason: '$g $level');
        }
      }
      final a = generatePuzzle(LevelConfig.forLevel(g, 34));
      final b = generatePuzzle(LevelConfig.forLevel(g, 34));
      expect(jsonEncode((a as dynamic).toJson()), jsonEncode((b as dynamic).toJson()));
    }
  });

  test('the daily puzzle rotates games and is the same all day', () {
    final days = [for (var i = 0; i < GameId.values.length; i++) LevelConfig.daily(DateTime(2026, 10, 24 + i)).game];
    expect(days.toSet().length, GameId.values.length);
    expect(LevelConfig.daily(DateTime(2026, 10, 24, 1)).seed, LevelConfig.daily(DateTime(2026, 10, 24, 23)).seed);
    expect(LevelConfig.daily(DateTime(2026, 10, 24)).dayKey, '2026-10-24');
  });
}
