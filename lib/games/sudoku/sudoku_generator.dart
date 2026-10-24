// Sudoku Six generator: a random full grid, then givens removed in random order while
// the puzzle keeps exactly one solution.
//
// Why several passes: one removal pass ends at a puzzle where no single given can go
// (uniqueness only gets harder as givens disappear, so a given that failed once can
// never be removed later in that pass). Where it ends depends on the grid and the
// order, so for sparse targets the generator runs more passes and keeps the sparsest
// result. All limits are pass/node counts and all randomness comes from Random(seed),
// so the same params + seed give the same puzzle on every device.

import 'dart:math';

import 'package:focus_and_play_mindgame/games/sudoku/sudoku_puzzle.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku_solver.dart';

/// Builds Sudoku Six puzzles. Pure Dart, safe to call inside `Isolate.run`.
class SudokuGenerator {
  SudokuGenerator._();

  /// Removal passes tried at most before returning the sparsest puzzle found. Targets
  /// of 9+ are reached in a few passes; for 8 (the proven 6×6 minimum) 400 passes hit
  /// it for ~80% of seeds (else 9 givens) in ≤ ~50 ms on desktop.
  static const int maxPasses = 400;

  /// Passes run on one full grid before drawing a new one; mixing both grids and
  /// orders reaches sparse targets sooner than either alone.
  static const int passesPerGrid = 6;

  /// Generates the puzzle for [p] and [seed]: unique, with exactly `p.givens` givens
  /// when the budget finds one, else the sparsest unique puzzle found (more givens).
  static SudokuPuzzle generate(SudokuParams p, int seed) {
    final rng = Random(seed);
    final target = p.givens.clamp(0, kSudokuCells);
    List<int> solution = const [];
    List<int>? bestGivens, bestSolution;
    var bestCount = kSudokuCells + 1;
    for (var pass = 0; pass < maxPasses; pass++) {
      if (pass % passesPerGrid == 0) solution = _randomSolution(rng);
      final givens = _reduce(solution, target, rng);
      final count = givens.where((v) => v != 0).length;
      if (count < bestCount) {
        bestCount = count;
        bestGivens = givens;
        bestSolution = solution;
      }
      if (bestCount <= target) break;
    }
    return SudokuPuzzle(
      givens: List<int>.unmodifiable(bestGivens!),
      solution: List<int>.unmodifiable(bestSolution!),
    );
  }

  /// A uniformly shuffled full grid: the solver fills an empty board trying digits in
  /// a fresh random order at every branch.
  static List<int> _randomSolution(Random rng) {
    final grid = SudokuSolver.solve(
      List<int>.filled(kSudokuCells, 0),
      digitOrder: () => _shuffled([1, 2, 3, 4, 5, 6], rng),
    );
    // An empty 6×6 board always has completions; null would mean a solver bug.
    return grid!;
  }

  /// One removal pass over [solution] in random order, stopping at [target] givens.
  static List<int> _reduce(List<int> solution, int target, Random rng) {
    final givens = List<int>.of(solution);
    final order = _shuffled(List<int>.generate(kSudokuCells, (i) => i), rng);
    var count = kSudokuCells;
    for (final cell in order) {
      if (count <= target) break;
      final v = givens[cell];
      givens[cell] = 0;
      if (SudokuSolver.countSolutions(givens, limit: 2) == 1) {
        count--;
      } else {
        givens[cell] = v; // removing it opens a second solution: keep it
      }
    }
    return givens;
  }

  /// Fisher–Yates with our own loop (not `List.shuffle`), so the order depends only on
  /// the Random's sequence and can't change with an SDK update.
  static List<int> _shuffled(List<int> list, Random rng) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
    return list;
  }
}
