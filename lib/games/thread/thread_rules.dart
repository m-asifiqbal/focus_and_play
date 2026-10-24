// Thread rules: move validation, the solved check and hints for the UI.
//
// Why separate from the generator: the UI calls these on every drag step, so they are
// small, allocation-light and never search. Hints compare against the stored solution,
// which is safe because generated puzzles have exactly one solution.

import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/common/hamiltonian.dart';
import 'package:focus_and_play_mindgame/games/thread/thread_puzzle.dart';

/// What a hint tells the UI: keep the first [keepLength] cells of the player's path and
/// highlight [next] as the cells that follow.
class ThreadHint {
  /// Creates a hint.
  const ThreadHint({required this.keepLength, required this.next});

  /// Length of the player's path prefix that matches the solution.
  final int keepLength;

  /// The solution cells right after that prefix (may be shorter near the end).
  final List<int> next;
}

/// Pure rule checks for Thread.
class ThreadRules {
  ThreadRules._();

  /// The number the path must reach next (1-based); 1 when [path] is empty and
  /// `maxNumber + 1` once K has been reached. Numbers met out of order are ignored,
  /// which cannot happen for paths built with [canAppend].
  static int nextNumber(ThreadPuzzle p, List<int> path) {
    var expected = 1;
    for (final c in path) {
      if (p.numbers[c] == expected) expected++;
    }
    return expected;
  }

  /// Whether [cell] may be appended to [path]: an empty path only takes the cell with 1;
  /// otherwise [cell] must be an edge neighbour of `path.last`, not already in the path,
  /// carry no number or exactly [nextNumber], and the cell with K is only allowed as the
  /// very last cell of the grid.
  static bool canAppend(ThreadPuzzle p, List<int> path, int cell) {
    final cells = p.cellCount;
    if (cell < 0 || cell >= cells) return false;
    final number = p.numbers[cell];
    if (path.isEmpty) return number == 1;
    if (path.length >= cells) return false;
    if (!isOrthogonalNeighbour(path.last, cell, p.size)) return false;
    if (path.contains(cell)) return false;
    if (number != null && number != nextNumber(p, path)) return false;
    if (number == p.maxNumber && path.length != cells - 1) return false;
    return true;
  }

  /// Solved = a Hamiltonian path that starts on 1, ends on K and meets the numbers in
  /// increasing order (so every number exactly once, 1..K).
  static bool isSolved(ThreadPuzzle p, List<int> path) {
    if (!isHamiltonianPath(path, p.size, p.size)) return false;
    var expected = 1;
    for (final c in path) {
      final number = p.numbers[c];
      if (number == null) continue;
      if (number != expected) return false;
      expected++;
    }
    return expected == p.maxNumber + 1 &&
        p.numbers[path.first] == 1 &&
        p.numbers[path.last] == p.maxNumber;
  }

  /// The longest prefix of [path] that matches the solution, plus the next [reveal]
  /// solution cells after it. The UI truncates the path to `keepLength` and highlights
  /// `next`.
  static ThreadHint hint(ThreadPuzzle p, List<int> path, {int reveal = 3}) {
    final sol = p.solution;
    var keep = 0;
    while (keep < path.length && keep < sol.length && path[keep] == sol[keep]) {
      keep++;
    }
    final end = (keep + reveal).clamp(keep, sol.length);
    return ThreadHint(keepLength: keep, next: sol.sublist(keep, end));
  }
}
