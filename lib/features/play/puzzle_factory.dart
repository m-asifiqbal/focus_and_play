// Maps a LevelSpec to its engine, generates the puzzle off the UI thread and
// builds the matching board controller + widget.

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../domain/level_config.dart';
import '../../games/bridges/bridges.dart';
import '../../games/quilt/quilt.dart';
import '../../games/sleuth/sleuth.dart';
import '../../games/sudoku/sudoku.dart';
import '../../games/thread/thread.dart';
import '../../games/twist/twist.dart';
import '../boards/bridges_board.dart';
import '../boards/quilt_board.dart';
import '../boards/sleuth_board.dart';
import '../boards/sudoku_board.dart';
import '../boards/thread_board.dart';
import '../boards/twist_board.dart';
import 'board_controller.dart';

/// Pure and deterministic: same spec → same puzzle.
Object generatePuzzle(LevelSpec spec) => switch (spec.knobs) {
  ThreadKnobs k => ThreadGenerator.generate(
    ThreadParams(size: k.size, extraNumbers: k.extraNumbers),
    spec.seed,
  ),
  QuiltKnobs k => QuiltGenerator.generate(
    QuiltParams(
      size: k.size,
      maxArea: k.maxArea,
      shapeClues: k.shapeClues,
      shapeOnly: k.shapeOnly,
    ),
    spec.seed,
  ),
  TwistKnobs k => TwistGenerator.generate(
    TwistParams(rows: k.rows, cols: k.cols, minLen: k.minLen, maxLen: k.maxLen),
    spec.seed,
  ),
  SudokuKnobs k => SudokuGenerator.generate(
    SudokuParams(givens: k.givens),
    spec.seed,
  ),
  BridgesKnobs k => BridgesGenerator.generate(
    BridgesParams(
      rows: k.rows,
      cols: k.cols,
      islands: k.islands,
      doubles: k.doubles,
    ),
    spec.seed,
  ),
  SleuthKnobs k => SleuthGenerator.generate(
    SleuthParams(
      length: k.length,
      candidates: k.candidates,
      tries: k.tries,
      assist: k.assist,
    ),
    spec.seed,
  ),
  _ => throw ArgumentError('Unknown knobs ${spec.knobs.runtimeType}'),
};

/// Under `flutter test` an isolate can't finish inside fake async time, so tests
/// generate on the spot (puzzles are deterministic either way).
final bool _inTest = Platform.environment.containsKey('FLUTTER_TEST');

/// Recently generated (or generating) puzzles, oldest first. Puzzles are
/// immutable and boards copy what they change, so one can back many attempts:
/// a restart, a replay, or the next level prefetched during the celebration.
final Map<String, Future<Object>> _cache = {};
const _cacheSize = 8;

String _cacheKey(LevelSpec s) =>
    '${s.game.key}/${s.level}/${s.dayKey}/${s.seed}';

/// The puzzle for [spec]: from the cache, else generated in a background isolate.
Future<Object> generatePuzzleAsync(LevelSpec spec) {
  final key = _cacheKey(spec);
  final hit = _cache.remove(key);
  if (hit != null) return _cache[key] = hit; // re-insert as most recent
  final future = _generateOffThread(spec);
  _cache[key] = future;
  if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
  // A failed generation must not stay cached.
  future.catchError((Object _) {
    if (identical(_cache[key], future)) _cache.remove(key);
    return Object();
  });
  return future;
}

/// Empties the cache. Tests call it per app: a future made inside one test's
/// fake-async zone never completes in the next test's zone.
@visibleForTesting
void clearPuzzleCache() => _cache.clear();

/// Starts building [spec]'s puzzle now so opening the level is instant.
void prefetchPuzzle(LevelSpec spec) => generatePuzzleAsync(spec).ignore();

/// Kept separate (and tiny) so the isolate closure captures only [spec].
Future<Object> _generateOffThread(LevelSpec spec) async {
  if (_inTest) return generatePuzzle(spec);
  try {
    return await Isolate.run(() => generatePuzzle(spec));
  } catch (_) {
    return generatePuzzle(spec);
  }
}

BoardController controllerFor(Object puzzle) => switch (puzzle) {
  ThreadPuzzle p => ThreadController(p),
  QuiltPuzzle p => QuiltController(p),
  TwistPuzzle p => TwistController(p),
  SudokuPuzzle p => SudokuController(p),
  SleuthPuzzle p => SleuthController(p),
  BridgesPuzzle p => BridgesController(p),
  _ => throw ArgumentError('Unknown puzzle ${puzzle.runtimeType}'),
};

Widget boardFor(BoardController c, {required int hintsLeft}) => switch (c) {
  ThreadController t => ThreadBoard(controller: t),
  QuiltController q => QuiltBoard(controller: q),
  TwistController t => TwistBoard(controller: t),
  SudokuController s => SudokuBoard(controller: s, hintsLeft: hintsLeft),
  SleuthController s => SleuthBoard(controller: s, hintsLeft: hintsLeft),
  BridgesController b => BridgesBoard(controller: b),
  _ => const SizedBox.shrink(),
};

/// One-line rule under the board.
String ruleLine(BoardController c) => switch (c) {
  ThreadController t =>
    'Connect 1 to ${t.puzzle.maxNumber} in order and fill every square.',
  QuiltController _ =>
    'Drag to stitch rectangles. Each patch holds exactly one clue.',
  TwistController _ => 'Find every hidden word — each tile is used once.',
  SudokuController _ => 'Each row, column and box holds 1–6 once.',
  BridgesController _ =>
    'Give every islet exactly its number of bridges and join them all.',
  SleuthController c =>
    c.puzzle.assist
        ? 'Tap a word, then Guess. Ruled-out words are crossed out for you.'
        : 'Tap a word, then Guess. Hold a word to cross it out.',
  _ => '',
};
