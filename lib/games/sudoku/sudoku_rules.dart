// Sudoku Six rules: solved check, clashes, pencil-mark candidates and hint cell choice.
//
// Why static, state-free functions: the UI owns the entered values (36 ints, 0 = empty)
// and asks these questions after every tap, so they stay cheap and never mutate input.

import 'package:focus_and_play_mindgame/games/sudoku/sudoku_puzzle.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku_solver.dart';

/// Rule checks and hints for a [SudokuPuzzle].
class SudokuRules {
  SudokuRules._();

  /// Solved = every cell holds 1..6, the givens are unchanged and nothing clashes.
  /// (A unique puzzle has only one such grid, its solution.)
  static bool isSolved(SudokuPuzzle p, List<int> values) {
    if (values.length != kSudokuCells) return false;
    for (var c = 0; c < kSudokuCells; c++) {
      final v = values[c];
      if (v < 1 || v > kSudokuSide) return false;
      if (p.givens[c] != 0 && p.givens[c] != v) return false;
    }
    return conflicts(values).isEmpty;
  }

  /// Filled cells whose digit also appears in their row, column or box, ascending.
  static Set<int> conflicts(List<int> values) {
    final out = <int>{};
    for (var c = 0; c < kSudokuCells; c++) {
      final v = values[c];
      if (v == 0) continue;
      for (final o in sudokuPeersOf[c]) {
        if (values[o] == v) {
          out.add(c);
          break;
        }
      }
    }
    return out;
  }

  /// Digits (ascending) not yet used by any peer of [cell] — the cell's own value is
  /// ignored, so a filled cell lists the digits it could be changed to.
  static Set<int> candidates(List<int> values, int cell) {
    var used = 0;
    for (final o in sudokuPeersOf[cell]) {
      used |= 1 << values[o];
    }
    return {
      for (var d = 1; d <= kSudokuSide; d++)
        if (used & (1 << d) == 0) d,
    };
  }

  /// The cell to reveal: [preferred] when it is empty or wrong and not a given; else
  /// the empty cell with the fewest candidates (ties → lowest index); else, on a full
  /// but wrong board, the lowest wrong cell. Null when solved.
  static int? hintCell(SudokuPuzzle p, List<int> values, {int? preferred}) {
    if (isSolved(p, values)) return null;
    if (preferred != null &&
        preferred >= 0 &&
        preferred < kSudokuCells &&
        p.givens[preferred] == 0 &&
        values[preferred] != p.solution[preferred]) {
      return preferred;
    }
    int? best;
    var bestCount = kSudokuSide + 1;
    for (var c = 0; c < kSudokuCells; c++) {
      if (values[c] != 0) continue;
      final n = candidates(values, c).length;
      if (n < bestCount) {
        best = c;
        bestCount = n;
      }
    }
    if (best != null) return best;
    for (var c = 0; c < kSudokuCells; c++) {
      if (values[c] != p.solution[c]) return c;
    }
    return null; // unreachable for a unique puzzle: a full, correct board is solved
  }
}
