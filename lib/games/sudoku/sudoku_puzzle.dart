// Sudoku Six value types: the puzzle (givens + solution) and the generator params.
//
// Why plain lists: puzzles cross isolate boundaries and get saved, so they round-trip
// through JSON made of ints and lists only.

/// A 6×6 Sudoku (boxes 2 rows × 3 columns, digits 1–6) with its unique solution.
class SudokuPuzzle {
  const SudokuPuzzle({required this.givens, required this.solution});

  /// 36 cells row-major, 0 = empty, 1..6 = given digit.
  final List<int> givens;

  /// 36 digits 1..6: the only completion of [givens].
  final List<int> solution;

  /// Number of given (pre-filled) cells.
  int get givenCount => givens.where((v) => v != 0).length;

  /// Whether [cell] is pre-filled (the player can't change it).
  bool isGiven(int cell) => givens[cell] != 0;

  Map<String, Object?> toJson() => {
    'givens': List<int>.of(givens),
    'solution': List<int>.of(solution),
  };

  factory SudokuPuzzle.fromJson(Map<String, Object?> j) => SudokuPuzzle(
    givens: List<int>.unmodifiable((j['givens'] as List).cast<int>()),
    solution: List<int>.unmodifiable((j['solution'] as List).cast<int>()),
  );
}

/// How many givens to aim for (fewer = harder).
class SudokuParams {
  const SudokuParams({required this.givens});

  /// Target given count, meant for 8..22. The generator stops removing at this count;
  /// when no unique puzzle that sparse is found within its budget it returns its
  /// sparsest unique puzzle instead (slightly more givens). 8 is the proven minimum
  /// for 6×6, and is rarely reached.
  final int givens;

  @override
  String toString() => 'SudokuParams(givens: $givens)';
}
