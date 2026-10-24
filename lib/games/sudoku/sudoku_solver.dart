// 6×6 Sudoku geometry and a bitmask solver shared by the generator and the rules.
//
// Why bitmasks: the generator asks "is this still unique?" dozens of times per puzzle,
// so each row/column/box keeps a 6-bit mask of used digits and the search always
// branches on the empty cell with the fewest candidates (naked singles fall out of
// that for free). A 6×6 grid then solves in a few dozen nodes.

/// Cells per side and in total.
const int kSudokuSide = 6;
const int kSudokuCells = 36;

/// Box shape: 2 rows × 3 columns, so 3 box-rows × 2 box-columns.
const int kSudokuBoxRows = 2;
const int kSudokuBoxCols = 3;

/// Row, column and box index of each cell.
final List<int> sudokuRowOf = List<int>.unmodifiable([
  for (var c = 0; c < kSudokuCells; c++) c ~/ kSudokuSide,
]);
final List<int> sudokuColOf = List<int>.unmodifiable([
  for (var c = 0; c < kSudokuCells; c++) c % kSudokuSide,
]);
final List<int> sudokuBoxOf = List<int>.unmodifiable([
  for (var c = 0; c < kSudokuCells; c++)
    (c ~/ kSudokuSide ~/ kSudokuBoxRows) * (kSudokuSide ~/ kSudokuBoxCols) +
        (c % kSudokuSide) ~/ kSudokuBoxCols,
]);

/// The 20-ish cells sharing a row, column or box with each cell (cell itself excluded),
/// ascending.
final List<List<int>> sudokuPeersOf = List<List<int>>.unmodifiable([
  for (var c = 0; c < kSudokuCells; c++)
    List<int>.unmodifiable([
      for (var o = 0; o < kSudokuCells; o++)
        if (o != c &&
            (sudokuRowOf[o] == sudokuRowOf[c] ||
                sudokuColOf[o] == sudokuColOf[c] ||
                sudokuBoxOf[o] == sudokuBoxOf[c]))
          o,
    ]),
]);

/// Bits 1..6 set: every digit allowed.
const int kSudokuAllDigits = 0x7E;

/// Population count for masks 0..127.
final List<int> _bits = List<int>.unmodifiable([
  for (var m = 0; m < 128; m++)
    [for (var b = 0; b < 7; b++) (m >> b) & 1].reduce((a, b) => a + b),
]);

/// Bitmask search over a 6×6 grid (0 = empty, 1..6 = digit).
class SudokuSolver {
  SudokuSolver._();

  /// Default node budget: far above what any 6×6 grid needs (a few hundred), so it
  /// only guards against a bug turning into a hang.
  static const int defaultNodeLimit = 200000;

  /// Counts completions of [grid] up to [limit]. Returns 0 when the grid already breaks
  /// a rule. When [nodeLimit] runs out the answer is [limit] — "not proven unique" — so
  /// callers asking `== 1` stay safe.
  static int countSolutions(
    List<int> grid, {
    int limit = 2,
    int nodeLimit = defaultNodeLimit,
  }) {
    final s = _Search.from(grid);
    if (s == null) return 0;
    s.run(limit, nodeLimit, null);
    return s.aborted ? limit : s.count;
  }

  /// A completion of [grid], or null when it has none (or [nodeLimit] runs out).
  /// With [digitOrder] the search tries digits in the order it returns for each
  /// branch — the generator passes a shuffle to get a random full grid.
  static List<int>? solve(
    List<int> grid, {
    List<int> Function()? digitOrder,
    int nodeLimit = defaultNodeLimit,
  }) {
    final s = _Search.from(grid);
    if (s == null) return null;
    s.keepFirst = true;
    s.run(1, nodeLimit, digitOrder);
    return s.first;
  }
}

/// Mutable search state: the grid plus used-digit masks per row, column and box.
class _Search {
  _Search(this.cells, this.rows, this.cols, this.boxes);

  final List<int> cells, rows, cols, boxes;
  var count = 0;
  var nodes = 0;
  var aborted = false;
  var keepFirst = false;
  List<int>? first;

  /// Null when [grid] already has a clash (or a value outside 0..6).
  static _Search? from(List<int> grid) {
    final rows = List<int>.filled(kSudokuSide, 0);
    final cols = List<int>.filled(kSudokuSide, 0);
    final boxes = List<int>.filled(kSudokuSide, 0);
    for (var c = 0; c < kSudokuCells; c++) {
      final v = grid[c];
      if (v == 0) continue;
      if (v < 1 || v > kSudokuSide) return null;
      final bit = 1 << v;
      final r = sudokuRowOf[c], k = sudokuColOf[c], b = sudokuBoxOf[c];
      if ((rows[r] | cols[k] | boxes[b]) & bit != 0) return null;
      rows[r] |= bit;
      cols[k] |= bit;
      boxes[b] |= bit;
    }
    return _Search(List<int>.of(grid), rows, cols, boxes);
  }

  void run(int limit, int nodeLimit, List<int> Function()? digitOrder) {
    const ascending = [1, 2, 3, 4, 5, 6];

    // True when the search should stop (limit reached or budget spent).
    bool search() {
      if (++nodes > nodeLimit) {
        aborted = true;
        return true;
      }
      var best = -1, bestCount = 7, bestMask = 0;
      for (var c = 0; c < kSudokuCells; c++) {
        if (cells[c] != 0) continue;
        final mask =
            ~(rows[sudokuRowOf[c]] |
                cols[sudokuColOf[c]] |
                boxes[sudokuBoxOf[c]]) &
            kSudokuAllDigits;
        final n = _bits[mask];
        if (n < bestCount) {
          best = c;
          bestCount = n;
          bestMask = mask;
          if (n <= 1) break; // dead end or forced: no better choice exists
        }
      }
      if (best < 0) {
        count++;
        if (keepFirst && first == null) first = List<int>.of(cells);
        return count >= limit;
      }
      if (bestCount == 0) return false;
      final r = sudokuRowOf[best], k = sudokuColOf[best], b = sudokuBoxOf[best];
      for (final d in digitOrder == null ? ascending : digitOrder()) {
        final bit = 1 << d;
        if (bestMask & bit == 0) continue;
        cells[best] = d;
        rows[r] |= bit;
        cols[k] |= bit;
        boxes[b] |= bit;
        final stop = search();
        cells[best] = 0;
        rows[r] &= ~bit;
        cols[k] &= ~bit;
        boxes[b] &= ~bit;
        if (stop) return true;
      }
      return false;
    }

    search();
  }
}
