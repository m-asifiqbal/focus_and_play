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

## Sleuth — `lib/games/sleuth/`
Wordle-style deduction on a *closed list*: one themed list of same-length words, one of
them the secret. The player never types — every guess is picked from the list, so the game
needs no dictionary. Feedback per letter: correct (right place), present (elsewhere),
absent (duplicates counted like Wordle). The list is drawn from the Twist word bank
(`kWordThemes`), one theme per puzzle.

```dart
enum SleuthMark { absent, present, correct }           // index = digit of a base-3 pattern
class SleuthGuess { final int word; final List<SleuthMark> marks; bool get isCorrect; toJson/fromJson }
class SleuthPuzzle { final String theme; final int length; final List<String> words; // A–Z, sorted
  final int secret; final int tries; final bool assist; String get answer; toJson/fromJson }

class SleuthParams { final int length;      // 4..8 (the word bank's range)
  final int candidates;                     // list size; raised to kSleuthMinCandidates (6), capped by the theme
  final int tries; final bool assist; }     // assist: the UI may cross out ruled-out words (easy tiers)
class SleuthGenerator {
  static SleuthPuzzle generate(SleuthParams p, int seed);
  static int maxCandidates(int length);     // the real ceiling for `candidates` at that length
}

class SleuthRules {
  static List<SleuthMark> score(String guess, String answer);
  static SleuthGuess guess(SleuthPuzzle p, int wordIndex);
  /// Words still consistent with ALL the feedback so far (the secret is always among them).
  static List<int> remaining(SleuthPuzzle p, List<SleuthGuess> history);
  static bool isSolved(SleuthPuzzle p, List<SleuthGuess> history);
  /// Hint: the word that minimises the worst-case candidates left (never peeks at the secret).
  /// -1 when solved or every word was tried.
  static int bestGuess(SleuthPuzzle p, List<SleuthGuess> history);
  /// Plays `bestGuess` against the secret; the generator uses it to prove the puzzle is
  /// solvable within `tries`, and the app reuses it to pick a *new* secret on "Try again".
  static List<SleuthGuess> greedyRun(SleuthPuzzle p, {int? maxGuesses});
}
```
"Unique" here means the *feedback pins the secret down*: after the hint strategy plays, one
candidate is left. The generator throws `StateError` if a param set cannot be solved within
its tries; `lib/domain/level_config.dart` only uses sets the tests prove out. A lost round
(`tries` used up) is replayed on the same list with another secret — see
`SleuthController.reset`.

## Bridges — `lib/games/bridges/`
Numbered islands on a grid (Hashi). Join islands in straight horizontal/vertical lines with
one or two bridges so each island has exactly its number, no bridge crosses another, and
all islands form one group. Islands refer to each other by index (row-major), so a puzzle is
two small lists plus the grid size. Import `bridges.dart` (the barrel) for everything.

```dart
class BridgesIsland { final int row, col, need; }            // need 1..8
class BridgesLink   { final int a, b, count; }                // a < b, count 1 or 2
class BridgesPuzzle { final int rows, cols; final List<BridgesIsland> islands; // row-major
  final List<BridgesLink> solution;                            // unique, sorted by (a, b)
  final BridgesGraph graph;   // visible pairs, crossings, per-island pairs (computed once)
  toJson/fromJson }                                            // constructor sorts + remaps, throws ArgumentError

class BridgesParams { final int rows, cols, islands; final double doubles; }  // doubles = share of 2-bridge links
class BridgesGenerator { static BridgesPuzzle generate(BridgesParams p, int seed); }
// If the grid can't hold `islands` (or no unique layout turns up) it asks for one fewer, so
// compare p.islands.length with the request. ~1 ms for 9×9 / 20 islands on desktop.

class BridgesRules {
  static List<(int, int)> pairs(BridgesPuzzle p);               // every pair that can be joined
  static bool cross(BridgesPuzzle p, int a1, int b1, int a2, int b2);
  static List<int> degrees(BridgesPuzzle p, List<BridgesLink> links);
  /// A tap on the gap between a and b: 0 → 1 → 2 → 0. Returns the SAME list instance when
  /// blocked (a crossing bridge is in the way) — the controller turns that into a message.
  static List<BridgesLink> cycle(BridgesPuzzle p, List<BridgesLink> links, int a, int b);
  static bool connected(BridgesPuzzle p, List<BridgesLink> links);
  /// Solved = every island has exactly its number AND all islands are connected.
  static bool isSolved(BridgesPuzzle p, List<BridgesLink> links);
  /// Placed links that are not part of the answer (the hint removes these first).
  static List<BridgesLink> wrongLinks(BridgesPuzzle p, List<BridgesLink> links);
  /// Next teachable step; `count` is the link's TOTAL (0 = remove a surplus bridge).
  static BridgesHint? hint(BridgesPuzzle p, List<BridgesLink> links);
}
enum BridgesHintKind { onlyNeighbour, fullIsland, forced, solution }
enum BridgesForcedWhy { neighbours, crossing, cutOff }          // set when kind == forced
class BridgesHint { final int island, a, b, count; final BridgesHintKind kind; final BridgesForcedWhy? why; }
class BridgesSolver { static int countSolutions(...); static BridgesSearch search(...); static List<BridgesLink>? solve(...); }
```
Uniqueness: every generated puzzle is proven to have one solution by `BridgesSolver`
(propagation + a deterministic node limit; a hit limit counts as "not unique" and the layout
is redrawn). The tests check the solver against a brute-force enumerator and every generated
puzzle against an independent depth-first solver.

Hints reason like a person from the bridges the player already placed (wrong ones are
ignored): an island with one open neighbour, an island whose need equals what its neighbours
can take, then degree/crossing and cut-off arguments; only if none fires does it fall back to
"this bridge is part of the answer". The UI shows it in two steps (spotlight + reason, then
"Show me" builds it free) — see `lib/features/boards/bridges_controller.dart`.
