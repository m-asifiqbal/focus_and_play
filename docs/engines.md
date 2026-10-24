# Puzzle engines — contract

Every engine is **pure Dart** (no `package:flutter` imports) under `lib/games/<game>/`,
so the app can generate puzzles inside `Isolate.run`. Engines are deterministic: the same
params + seed must give the same puzzle on every device. Use only `dart:math` `Random(seed)`
passed in by the caller; never `DateTime.now()`, never a time budget (use iteration/node
counts as limits, and they must be deterministic too). Never iterate a `Set`/`Map` whose
order depends on hashing of non-int keys in a way that changes results.

Cells are row-major indices `r * cols + c` (helpers in `lib/games/common/grid.dart`;
random Hamiltonian paths in `lib/games/common/hamiltonian.dart`).

Every puzzle must have **exactly one solution** under the game's rules (verified by a
solver that counts solutions up to 2 with a deterministic node limit; when the limit is hit,
treat the puzzle as "not proven unique" and keep adding clues / regenerate).

Generation must take < 300 ms on a mid-range phone for the largest size (tests should
assert a generous bound on desktop, e.g. average < 150 ms over 20 seeds).

Each puzzle class has `toJson()` / `fromJson()` (plain maps/lists/ints/strings only).

Tests live in `test/games/<game>/` and cover: many seeds × every size produce valid, unique
puzzles; determinism (same seed → identical JSON); rules (`isSolved`, move validation, hints).
Run with `flutter test --no-pub test/games/<game>`.

---

## Thread — `lib/games/thread/`
One path through every cell of an n×n grid, passing numbered cells in order 1→K
(1 is the start, K the end).

```dart
class ThreadPuzzle {
  final int size;                 // n (grid is n×n), 4..8
  final Map<int, int> numbers;    // cell -> number (1..k); 1 = start, k = end
  final List<int> solution;       // the unique path, length n*n, solution.first has 1, last has k
  int get maxNumber;              // k
  int get cellCount;              // n*n
  Map<String, Object?> toJson(); factory ThreadPuzzle.fromJson(Map<String, Object?> j);
}

class ThreadParams {
  final int size;          // 4..8
  final int extraNumbers;  // numbers added beyond the minimum needed for uniqueness (0 = hardest)
  const ThreadParams({required this.size, this.extraNumbers = 0});
}

class ThreadGenerator {
  static ThreadPuzzle generate(ThreadParams p, int seed);
}

class ThreadRules {
  /// The number the path must reach next (1-based); 1 when path is empty.
  static int nextNumber(ThreadPuzzle p, List<int> path);
  /// Whether [cell] may be appended to [path]: path empty → only the cell with 1;
  /// otherwise cell is an edge neighbour of path.last, not already in path, and if it
  /// carries a number it must equal nextNumber; the cell with K may only be entered as
  /// the very last cell (path.length == n*n - 1).
  static bool canAppend(ThreadPuzzle p, List<int> path, int cell);
  /// Solved = Hamiltonian, starts on 1, ends on K, numbers in increasing order.
  static bool isSolved(ThreadPuzzle p, List<int> path);
  /// Hint: the longest prefix of [path] that matches the solution, plus the next
  /// [reveal] solution cells after it. UI truncates the path to keepLength and highlights next.
  static ThreadHint hint(ThreadPuzzle p, List<int> path, {int reveal = 3});
}
class ThreadHint { final int keepLength; final List<int> next; }
```

## Quilt — `lib/games/quilt/`
Split an n×n grid into rectangles. Each rectangle contains exactly one clue cell. A clue
shows the rectangle's area, and optionally its shape: square (w==h), tall (h>w), wide (w>h).
A shape-only clue (area null) is allowed; a clue always has at least one of area/shape.

```dart
enum QuiltShape { square, tall, wide }
class QuiltRect { final int row, col, width, height; // top-left + size, all in cells
  int get area; bool contains(int cell, int cols); Iterable<int> cells(int cols);
  QuiltShape get shape; // square when w==h …
  toJson/fromJson; == and hashCode by value }
class QuiltClue { final int cell; final int? area; final QuiltShape? shape; toJson/fromJson }
class QuiltPuzzle { final int size; final List<QuiltClue> clues; final List<QuiltRect> solution; // solution[i] belongs to clues[i]
  toJson/fromJson }

class QuiltParams {
  final int size;            // 5..8
  final int maxArea;         // largest rectangle area allowed, e.g. 6..12
  final double shapeClues;   // 0..1 share of clues that also show a shape
  final double shapeOnly;    // 0..1 share of shape clues that hide the area (harder)
}
class QuiltGenerator { static QuiltPuzzle generate(QuiltParams p, int seed); } // areas >= 2

class QuiltRules {
  /// Index of the single clue inside [r], or null when it holds 0 or 2+ clues.
  static int? clueIn(QuiltPuzzle p, QuiltRect r);
  /// A rectangle the player drew is "fitting" when it holds exactly one clue and matches
  /// that clue's area/shape. (UI colours fitting patches; others show as warning.)
  static bool fits(QuiltPuzzle p, QuiltRect r);
  /// Solved = rectangles don't overlap, cover the whole grid, and every one fits.
  static bool isSolved(QuiltPuzzle p, List<QuiltRect> placed);
  /// Hint: a solution rectangle that is not yet placed exactly (prefer one whose clue has the
  /// fewest placements left, else first by clue order). Null when solved.
  static QuiltRect? hint(QuiltPuzzle p, List<QuiltRect> placed);
}
```

## Twist — `lib/games/twist/`
A rows×cols letter grid fully partitioned into hidden words. Each word is a path of
edge-adjacent cells (no diagonals); every tile belongs to exactly one word.
Board = Hamiltonian path cut into pieces whose lengths match chosen words.

```dart
class TwistWord { final String word; final List<int> cells; toJson/fromJson }   // cells in reading order
class TwistPuzzle { final int rows, cols; final List<String> letters; // rows*cols upper-case single letters
  final List<TwistWord> words; final String theme; toJson/fromJson }

class TwistParams { final int rows, cols; final int minLen, maxLen; } // e.g. 4×4 (4..6) up to 6×6 (4..8)
class TwistGenerator { static TwistPuzzle generate(TwistParams p, int seed); }

class TwistRules {
  /// Whether [cell] may extend the traced path: empty → any cell not in [found] words;
  /// else edge neighbour of last, not already traced, not part of a found word.
  static bool canAppend(TwistPuzzle p, List<int> traced, Set<int> foundWordIdx, int cell);
  /// Index of the word whose cells equal [traced] exactly (same order), not yet found; else null.
  static int? match(TwistPuzzle p, List<int> traced, Set<int> foundWordIdx);
  /// Index of an unfound word whose letters equal the traced letters but on different cells
  /// ("right word, other tiles") — lets the UI say so kindly. Else null.
  static int? sameWordOtherCells(TwistPuzzle p, List<int> traced, Set<int> foundWordIdx);
  static bool isSolved(TwistPuzzle p, Set<int> foundWordIdx);
  /// Hint: the unfound word to reveal next (shortest first) and how many of its letters to show:
  /// each call for the same word reveals one more letter, up to the whole word.
  static TwistHint hint(TwistPuzzle p, Set<int> foundWordIdx, Map<int, int> revealed);
}
class TwistHint { final int wordIndex; final int lettersShown; }
```
Word bank: `lib/games/twist/word_bank.dart` — `const Map<String, List<String>> kWordThemes`
with ≥ 10 kid-friendly themes (Ocean, Animals, Food, Space, Weather, Music, Sports, Garden,
Travel, Home…), each with ≥ 45 common, unambiguous, family-friendly English nouns of length
4–8 (upper-case, A–Z only, no plurals that are just +S of another word in the theme). The
generator picks one theme per puzzle and words whose lengths match the cut lengths; it must
retry with other cuts/themes deterministically if lengths can't be matched. No word may
appear twice in a puzzle. Uniqueness here means: the intended partition is the only way to
read the board as words *from the puzzle's list* (verify by searching for each word's
alternative placements: every word must have exactly one valid path on the board given the
others — reject boards where any word can be traced on a different cell set).

## Sudoku Six — `lib/games/sudoku/`
6×6 grid, boxes are 2 rows × 3 columns. Digits 1–6.

```dart
class SudokuPuzzle { final List<int> givens; // 36, 0 = empty
  final List<int> solution; // 36 toJson/fromJson }
class SudokuParams { final int givens; } // 8..22 target count (fewer = harder); generator may end with
                                          // slightly more if needed for uniqueness
class SudokuGenerator { static SudokuPuzzle generate(SudokuParams p, int seed); }
class SudokuRules {
  static bool isSolved(SudokuPuzzle p, List<int> values);           // values: 36, 0 empty
  static Set<int> conflicts(List<int> values);                       // cells clashing in row/col/box
  /// Candidates still possible for [cell] given [values].
  static Set<int> candidates(List<int> values, int cell);
  /// Hint cell: [preferred] if it is empty or wrong and not a given; else the empty cell with
  /// the fewest candidates (ties → lowest index). Null when solved.
  static int? hintCell(SudokuPuzzle p, List<int> values, {int? preferred});
}
```
