// Sudoku Six generator: valid solutions, givens taken from them, exactly one solution
// (checked by an independent brute-force counter), target counts, determinism, JSON.

// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku.dart';

/// Plain cell-by-cell backtracking, deliberately unlike the engine's bitmask solver.
int _bruteForceCount(List<int> givens, {int limit = 2}) {
  final g = List<int>.of(givens);
  var count = 0;
  bool fits(int cell, int d) {
    final r = cell ~/ 6, c = cell % 6;
    for (var i = 0; i < 6; i++) {
      if (g[r * 6 + i] == d || g[i * 6 + c] == d) return false;
    }
    final br = r ~/ 2 * 2, bc = c ~/ 3 * 3;
    for (var dr = 0; dr < 2; dr++) {
      for (var dc = 0; dc < 3; dc++) {
        if (g[(br + dr) * 6 + bc + dc] == d) return false;
      }
    }
    return true;
  }

  bool go(int cell) {
    if (cell == 36) return ++count >= limit;
    if (g[cell] != 0) return go(cell + 1);
    for (var d = 1; d <= 6; d++) {
      if (!fits(cell, d)) continue;
      g[cell] = d;
      final stop = go(cell + 1);
      g[cell] = 0;
      if (stop) return true;
    }
    return false;
  }

  go(0);
  return count;
}

void _expectValidSolution(List<int> s, String why) {
  expect(s, hasLength(36), reason: why);
  final units = <List<int>>[
    for (var r = 0; r < 6; r++) [for (var c = 0; c < 6; c++) r * 6 + c],
    for (var c = 0; c < 6; c++) [for (var r = 0; r < 6; r++) r * 6 + c],
    for (var br = 0; br < 6; br += 2)
      for (var bc = 0; bc < 6; bc += 3)
        [
          for (var dr = 0; dr < 2; dr++)
            for (var dc = 0; dc < 3; dc++) (br + dr) * 6 + bc + dc,
        ],
  ];
  for (final u in units) {
    expect(u.map((c) => s[c]).toSet(), {1, 2, 3, 4, 5, 6}, reason: '$why $u');
  }
}

void main() {
  const targets = [8, 9, 10, 12, 14, 16, 18, 20, 22];

  test('many seeds x every target give valid, unique puzzles', () {
    for (final target in targets) {
      for (var seed = 0; seed < 25; seed++) {
        final why = 'givens $target seed $seed';
        final p = SudokuGenerator.generate(SudokuParams(givens: target), seed);
        _expectValidSolution(p.solution, why);
        expect(p.givens, hasLength(36), reason: why);
        for (var c = 0; c < 36; c++) {
          if (p.givens[c] != 0) expect(p.givens[c], p.solution[c], reason: why);
        }
        expect(_bruteForceCount(p.givens), 1, reason: '$why not unique');
        if (target >= 9) {
          expect(p.givenCount, target, reason: why);
        } else {
          expect(
            p.givenCount,
            inInclusiveRange(target, target + 1),
            reason: why,
          );
        }
      }
    }
  });

  test('reports how sparse the hardest targets get', () {
    for (final target in [8, 9]) {
      var total = 0, hits = 0;
      for (var seed = 0; seed < 40; seed++) {
        final n = SudokuGenerator.generate(
          SudokuParams(givens: target),
          seed,
        ).givenCount;
        total += n;
        if (n == target) hits++;
      }
      print(
        'Sudoku target $target: average ${(total / 40).toStringAsFixed(2)} '
        'givens, exact on $hits/40 seeds',
      );
      expect(total / 40, lessThan(target + 0.5));
    }
  });

  test('targets outside 8..22 still give unique puzzles', () {
    for (final target in [0, 30, 36]) {
      final p = SudokuGenerator.generate(SudokuParams(givens: target), 1);
      expect(_bruteForceCount(p.givens), 1);
      expect(p.givenCount, greaterThanOrEqualTo(target));
    }
  });

  test('same seed gives the same puzzle, other seeds differ', () {
    for (final target in [8, 12, 22]) {
      final a = SudokuGenerator.generate(SudokuParams(givens: target), 5);
      final b = SudokuGenerator.generate(SudokuParams(givens: target), 5);
      expect(a.toJson(), b.toJson());
      final others = {
        for (var s = 0; s < 10; s++)
          jsonEncode(
            SudokuGenerator.generate(SudokuParams(givens: target), s).toJson(),
          ),
      };
      expect(others.length, 10);
    }
  });

  test('JSON round trip through a string keeps the puzzle', () {
    final p = SudokuGenerator.generate(const SudokuParams(givens: 10), 3);
    final decoded = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
    final back = SudokuPuzzle.fromJson(decoded);
    expect(back.toJson(), p.toJson());
    expect(back.givenCount, 10);
  });

  test('solver counts, solves and respects its node budget', () {
    final p = SudokuGenerator.generate(const SudokuParams(givens: 12), 4);
    expect(SudokuSolver.countSolutions(p.givens), 1);
    expect(SudokuSolver.solve(p.givens), p.solution);
    expect(SudokuSolver.countSolutions(List<int>.filled(36, 0)), 2);
    expect(SudokuSolver.countSolutions(p.solution), 1);
    final clash = List<int>.filled(36, 0)
      ..[0] = 3
      ..[5] = 3;
    expect(SudokuSolver.countSolutions(clash), 0);
    expect(SudokuSolver.solve(clash), isNull);
    // Out of budget = "not proven unique".
    expect(SudokuSolver.countSolutions(p.givens, nodeLimit: 2), 2);
  });

  test('generation with 9 givens averages well under 150 ms', () {
    SudokuGenerator.generate(const SudokuParams(givens: 9), 999); // JIT warm-up
    for (final target in [9, 8]) {
      final sw = Stopwatch()..start();
      for (var s = 0; s < 20; s++) {
        SudokuGenerator.generate(SudokuParams(givens: target), 1000 + s);
      }
      final avgMs = sw.elapsedMicroseconds / 20 / 1000;
      print(
        'Sudoku givens $target: ${avgMs.toStringAsFixed(2)} ms average '
        'over 20 seeds',
      );
      expect(avgMs, lessThan(150));
    }
  });
}
