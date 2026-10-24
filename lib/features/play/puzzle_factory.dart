// Maps a LevelSpec to its engine, generates the puzzle off the UI thread and
// builds the matching board controller + widget.

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../domain/level_config.dart';
import '../../games/quilt/quilt.dart';
import '../../games/sudoku/sudoku.dart';
import '../../games/thread/thread.dart';
import '../../games/twist/twist.dart';
import '../boards/quilt_board.dart';
import '../boards/sudoku_board.dart';
import '../boards/thread_board.dart';
import '../boards/twist_board.dart';
import 'board_controller.dart';

/// Pure and deterministic: same spec → same puzzle.
Object generatePuzzle(LevelSpec spec) => switch (spec.knobs) {
      ThreadKnobs k => ThreadGenerator.generate(ThreadParams(size: k.size, extraNumbers: k.extraNumbers), spec.seed),
      QuiltKnobs k => QuiltGenerator.generate(QuiltParams(size: k.size, maxArea: k.maxArea, shapeClues: k.shapeClues, shapeOnly: k.shapeOnly), spec.seed),
      TwistKnobs k => TwistGenerator.generate(TwistParams(rows: k.rows, cols: k.cols, minLen: k.minLen, maxLen: k.maxLen), spec.seed),
      SudokuKnobs k => SudokuGenerator.generate(SudokuParams(givens: k.givens), spec.seed),
      _ => throw ArgumentError('Unknown knobs ${spec.knobs.runtimeType}'),
    };

/// Under `flutter test` an isolate can't finish inside fake async time, so tests
/// generate on the spot (puzzles are deterministic either way).
final bool _inTest = Platform.environment.containsKey('FLUTTER_TEST');

/// Generates in a background isolate; falls back to this isolate if that fails.
Future<Object> generatePuzzleAsync(LevelSpec spec) async {
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
      _ => throw ArgumentError('Unknown puzzle ${puzzle.runtimeType}'),
    };

Widget boardFor(BoardController c, {required int hintsLeft}) => switch (c) {
      ThreadController t => ThreadBoard(controller: t),
      QuiltController q => QuiltBoard(controller: q),
      TwistController t => TwistBoard(controller: t),
      SudokuController s => SudokuBoard(controller: s, hintsLeft: hintsLeft),
      _ => const SizedBox.shrink(),
    };

/// One-line rule under the board.
String ruleLine(BoardController c) => switch (c) {
      ThreadController t => 'Connect 1 to ${t.puzzle.maxNumber} in order and fill every square.',
      QuiltController _ => 'Drag to stitch rectangles. Each patch holds exactly one clue.',
      TwistController _ => 'Find every hidden word — each tile is used once.',
      SudokuController _ => 'Each row, column and box holds 1–6 once.',
      _ => '',
    };
