// Sudoku Six rules: isSolved, conflicts (row, column, 2×3 box), candidates, hint cell.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sudoku/sudoku.dart';

void main() {
  final p = SudokuGenerator.generate(const SudokuParams(givens: 12), 21);
  final firstEmpty = p.givens.indexOf(0);

  test('isSolved only for the full, clash-free grid that keeps the givens', () {
    expect(SudokuRules.isSolved(p, p.solution), isTrue);
    expect(SudokuRules.isSolved(p, p.givens), isFalse);
    expect(
      SudokuRules.isSolved(p, List.of(p.solution)..[firstEmpty] = 0),
      isFalse,
    );
    // Swap two digits in a row: still full, but clashes appear.
    final swapped = List.of(p.solution);
    final t = swapped[0];
    swapped[0] = swapped[1];
    swapped[1] = t;
    expect(SudokuRules.isSolved(p, swapped), isFalse);
    expect(SudokuRules.isSolved(p, const []), isFalse);
  });

  test('conflicts flag both cells of a row, column and box clash', () {
    final empty = List<int>.filled(36, 0);
    expect(SudokuRules.conflicts(empty), isEmpty);
    expect(SudokuRules.conflicts(p.solution), isEmpty);
    expect(SudokuRules.conflicts(p.givens), isEmpty);

    expect(
      SudokuRules.conflicts(
        List.of(empty)
          ..[0] = 4
          ..[5] = 4,
      ),
      {0, 5},
    ); // row
    expect(
      SudokuRules.conflicts(
        List.of(empty)
          ..[2] = 4
          ..[32] = 4,
      ),
      {2, 32},
    ); // col
    expect(
      SudokuRules.conflicts(
        List.of(empty)
          ..[0] = 4
          ..[8] = 4,
      ),
      {0, 8},
    ); // box
    // Same digit in different boxes, rows and columns: fine.
    expect(
      SudokuRules.conflicts(
        List.of(empty)
          ..[0] = 4
          ..[9] = 4,
      ),
      isEmpty,
    );
    expect(
      SudokuRules.conflicts(
        List.of(empty)
          ..[2] = 4
          ..[15] = 4,
      ),
      isEmpty,
    );
  });

  test(
    'candidates exclude row, column and box digits, not the cell itself',
    () {
      expect(SudokuRules.candidates(List<int>.filled(36, 0), 7), {
        1,
        2,
        3,
        4,
        5,
        6,
      });
      final v = List<int>.filled(36, 0)
        ..[7] =
            6 // the cell itself: ignored
        ..[10] =
            1 // same row
        ..[31] =
            2 // same column
        ..[2] =
            3 // same box (rows 0-1, cols 0-2)
        ..[35] = 4; // unrelated
      expect(SudokuRules.candidates(v, 7), {4, 5, 6});
      // On a real puzzle the solution digit is always a candidate.
      for (var c = 0; c < 36; c++) {
        if (p.givens[c] == 0) {
          expect(SudokuRules.candidates(p.givens, c), contains(p.solution[c]));
        }
      }
      expect(SudokuRules.candidates(p.solution, 0), {p.solution[0]});
    },
  );

  test('hintCell prefers the chosen cell when it is empty or wrong', () {
    expect(
      SudokuRules.hintCell(p, p.givens, preferred: firstEmpty),
      firstEmpty,
    );
    final wrong = List.of(p.givens)
      ..[firstEmpty] = p.solution[firstEmpty] % 6 + 1;
    expect(SudokuRules.hintCell(p, wrong, preferred: firstEmpty), firstEmpty);
  });

  test('hintCell falls back to the most constrained empty cell', () {
    int expected(List<int> values) {
      var best = -1, bestN = 99;
      for (var c = 0; c < 36; c++) {
        if (values[c] != 0) continue;
        final n = SudokuRules.candidates(values, c).length;
        if (n < bestN) {
          best = c;
          bestN = n;
        }
      }
      return best;
    }

    final given = p.givens.indexWhere((v) => v != 0);
    expect(SudokuRules.hintCell(p, p.givens), expected(p.givens));
    expect(
      SudokuRules.hintCell(p, p.givens, preferred: given),
      expected(p.givens),
    );
    final right = List.of(p.givens)..[firstEmpty] = p.solution[firstEmpty];
    expect(
      SudokuRules.hintCell(p, right, preferred: firstEmpty),
      expected(right),
    );
    // Ties go to the lowest index: on an empty grid every cell has 6 candidates.
    final blank = SudokuPuzzle(
      givens: List.filled(36, 0),
      solution: p.solution,
    );
    expect(SudokuRules.hintCell(blank, List.filled(36, 0)), 0);
  });

  test('hintCell on a full but wrong board points at the first wrong cell', () {
    final full = List.of(p.solution);
    final free = [
      for (var c = 0; c < 36; c++)
        if (p.givens[c] == 0) c,
    ];
    full[free[1]] = full[free[1]] % 6 + 1;
    full[free[3]] = full[free[3]] % 6 + 1;
    expect(SudokuRules.hintCell(p, full), free[1]);
  });

  test('hintCell is null once solved', () {
    expect(SudokuRules.hintCell(p, p.solution), isNull);
    expect(SudokuRules.hintCell(p, p.solution, preferred: 3), isNull);
  });
}
