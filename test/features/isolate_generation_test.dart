// The new puzzles must survive Isolate.run: puzzle_factory generates off the main thread
// and, on ANY failure, quietly falls back to generating on the UI thread — so a puzzle
// that could not cross the isolate boundary would not fail, it would just jank. This
// test makes that failure loud, for one level per tier of every game.

import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/domain/game_id.dart';
import 'package:focus_and_play_mindgame/domain/level_config.dart';
import 'package:focus_and_play_mindgame/features/play/puzzle_factory.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';

Object _build(LevelSpec c) => generatePuzzle(c);

Object _json(Object p) => switch (p) {
  SleuthPuzzle p => p.toJson(),
  BridgesPuzzle p => p.toJson(),
  _ => p.runtimeType,
};

void main() {
  test('twelve days of daily puzzles (two full rotations) all build', () async {
    final seen = <GameId>{};
    for (var d = 0; d < 12; d++) {
      final spec = LevelConfig.daily(DateTime(2026, 10, 1 + d));
      seen.add(spec.game);
      final puzzle = await Isolate.run(() => _build(spec));
      expect(
        controllerFor(puzzle).solved,
        isFalse,
        reason: '${spec.game.title} on day $d starts unsolved',
      );
    }
    expect(seen, GameId.values.toSet(), reason: 'every game gets a daily');
  });

  for (final game in [GameId.sleuth, GameId.bridges]) {
    for (final level in [1, 16, 31, 46, 60]) {
      test(
        '${game.title} level $level is built identically in an isolate',
        () async {
          final config = LevelConfig.forLevel(game, level);
          final remote = await Isolate.run(() => _build(config));
          final local = _build(config);
          expect(remote.runtimeType, local.runtimeType);
          expect(_json(remote), _json(local));
        },
      );
    }
  }
}
