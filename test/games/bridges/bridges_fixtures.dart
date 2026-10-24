// Hand-made Bridges puzzles shared by the engine tests, each drawn in a comment so the
// expected answers can be checked by eye. Not named `*_test.dart` (helper, not a test).

import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';

/// Builds a puzzle from `(row, col, need)` islands (any order) and `(a, b, count)`
/// links given as indices into that list.
BridgesPuzzle makePuzzle(
  int rows,
  int cols,
  List<(int, int, int)> islands, [
  List<(int, int, int)> links = const [],
]) => BridgesPuzzle(
  rows: rows,
  cols: cols,
  islands: [
    for (final (r, c, n) in islands) BridgesIsland(row: r, col: c, need: n),
  ],
  solution: [
    for (final (a, b, n) in links)
      a < b ? BridgesLink(a, b, n) : BridgesLink(b, a, n),
  ],
);

/// Six islands on 5×5; unique answer uses every visible pair:
/// ```
/// . 2 - 3 .      islands 0:(0,1)=2  1:(0,3)=3
/// . | . H .                2:(2,1)=4  3:(2,3)=4
/// . 4 = 4 .                4:(4,1)=2  5:(4,4)=1
/// . | . . .
/// . 2 - - 1      (H and = are double bridges)
/// ```
BridgesPuzzle smallPuzzle() => makePuzzle(
  5,
  5,
  [(0, 1, 2), (0, 3, 3), (2, 1, 4), (2, 3, 4), (4, 1, 2), (4, 4, 1)],
  [(0, 1, 1), (0, 2, 1), (1, 3, 2), (2, 3, 2), (2, 4, 1), (4, 5, 1)],
);

/// Four corner islands that each need 2. Every island is satisfied by two bridges
/// in several ways, but only the ring of four single bridges is one group.
/// ```
/// 2 - - 2      0:(0,0)  1:(0,3)
/// |     |
/// 2 - - 2      2:(3,0)  3:(3,3)
/// ```
/// (The other two degree-correct arrangements are double bridges on opposite sides.)
BridgesPuzzle ringPuzzle() => makePuzzle(
  4,
  4,
  [(0, 0, 2), (0, 3, 2), (3, 0, 2), (3, 3, 2)],
  [(0, 1, 1), (0, 2, 1), (1, 3, 1), (2, 3, 1)],
);

/// A hub with four single-bridge arms: unique, and the hub needs all four.
BridgesPuzzle plusPuzzle() => makePuzzle(
  5,
  5,
  [(0, 2, 1), (2, 0, 1), (2, 2, 4), (2, 4, 1), (4, 2, 1)],
  [(0, 2, 1), (1, 2, 1), (2, 3, 1), (2, 4, 1)],
);

/// Two islands that need two bridges each: the single double bridge.
BridgesPuzzle doublePairPuzzle() =>
    makePuzzle(1, 3, [(0, 0, 2), (0, 2, 2)], [(0, 1, 2)]);

/// Two islands that need three bridges each: impossible (at most 2 per pair).
BridgesPuzzle impossiblePuzzle() => makePuzzle(1, 3, [(0, 0, 3), (0, 2, 3)]);

/// A 3×5 ladder with two different valid answers (no stored solution).
/// ```
/// 2 . 3 . 2      0 1 2
/// . . . . .
/// 2 . 2 . 1      3 4 5
/// ```
BridgesPuzzle ladderPuzzle() => makePuzzle(3, 5, [
  (0, 0, 2),
  (0, 2, 3),
  (0, 4, 2),
  (2, 0, 2),
  (2, 2, 2),
  (2, 4, 1),
]);

/// Eight islands round the edge of 5×5 plus the two chords through the middle, which
/// cross each other. Islands, row-major: P(0,0) N(0,2) Q(0,4) W(2,0) E(2,4) R(4,0)
/// S(4,2) T(4,4). With every need 2 the unique answer is the ring round the edge.
BridgesPuzzle chordsPuzzle(List<int> needs) => makePuzzle(5, 5, [
  (0, 0, needs[0]),
  (0, 2, needs[1]),
  (0, 4, needs[2]),
  (2, 0, needs[3]),
  (2, 4, needs[4]),
  (4, 0, needs[5]),
  (4, 2, needs[6]),
  (4, 4, needs[7]),
]);

/// A tree of six islands on 5×5 where the first steps need different kinds of
/// reasoning (see the hint tests):
/// ```
/// . . . . .      islands 0:(1,0)=3  1:(1,2)=3  2:(1,4)=3
/// 3 - 3 - 3                3:(3,2)=1  4:(4,0)=2  5:(4,4)=2
/// H . | . H
/// H . 1 . H
/// 2 . . . 2
/// ```
BridgesPuzzle forcedPuzzle() => makePuzzle(
  5,
  5,
  [(1, 0, 3), (1, 2, 3), (1, 4, 3), (3, 2, 1), (4, 0, 2), (4, 4, 2)],
  [(0, 1, 1), (0, 4, 2), (1, 2, 1), (1, 3, 1), (2, 5, 2)],
);

/// Eight islands on 6×6. A bridge drawn along row 2 (island 3 to 4) blocks island 1's
/// way down to island 6, which leaves it two neighbours for three bridges (see the
/// hint tests).
/// ```
/// . 2 - 3 = 3      islands 0:(0,1)=2  1:(0,3)=3  2:(0,5)=3  3:(2,2)=2
/// . | . . . |                4:(2,5)=4  5:(4,1)=2  6:(4,3)=1  7:(4,5)=1
/// . | 2 = = 4
/// . | . . . |
/// . 2 - 1 . 1
/// ```
BridgesPuzzle crossingPuzzle() => makePuzzle(
  6,
  6,
  [
    (0, 1, 2),
    (0, 3, 3),
    (0, 5, 3),
    (2, 2, 2),
    (2, 5, 4),
    (4, 1, 2),
    (4, 3, 1),
    (4, 5, 1),
  ],
  [(0, 1, 1), (0, 5, 1), (1, 2, 2), (2, 4, 1), (3, 4, 2), (4, 7, 1), (5, 6, 1)],
);

/// Seven islands on 5×5 where the two doubled bridges at the top leave a group that
/// would be sealed off by a double bridge down the right side (see the hint tests).
/// ```
/// . 2 = = 4      islands 0:(0,1)=2  1:(0,4)=4  2:(2,0)=2  3:(2,4)=4
/// . . . . H                4:(4,0)=2  5:(4,2)=2  6:(4,4)=2
/// 2 - - - 4
/// | . . . |
/// 2 - 2 - 2
/// ```
BridgesPuzzle sealedPuzzle() => makePuzzle(
  5,
  5,
  [(0, 1, 2), (0, 4, 4), (2, 0, 2), (2, 4, 4), (4, 0, 2), (4, 2, 2), (4, 4, 2)],
  [(0, 1, 2), (1, 3, 2), (2, 3, 1), (2, 4, 1), (3, 6, 1), (4, 5, 1), (5, 6, 1)],
);
