// Thread generator: a random Hamiltonian path plus the fewest numbers (found greedily)
// that make it the only solution.
//
// Why this shape: numbering only the two ends almost never pins the path down, so we
// ask the solver for a *different* path and add a number that rules it out, repeating
// until the solver proves uniqueness; then we drop numbers that later fixes made
// redundant. Numbers are always renumbered 1..K along the intended path, so it stays a
// solution throughout. Everything is driven by one `Random(seed)` and node-count
// limits, so a seed gives the same puzzle everywhere.

import 'dart:math';
import 'dart:typed_data';

import 'package:focus_and_play_mindgame/games/common/hamiltonian.dart';
import 'package:focus_and_play_mindgame/games/thread/thread_puzzle.dart';
import 'package:focus_and_play_mindgame/games/thread/thread_solver.dart';

/// Generation settings for a Thread puzzle.
class ThreadParams {
  /// [size] is the grid side (4..8 in the app; 2..8 accepted).
  const ThreadParams({required this.size, this.extraNumbers = 0});

  /// Grid side n (the grid is n×n).
  final int size;

  /// Numbers added beyond the minimum needed for uniqueness (0 = hardest).
  final int extraNumbers;
}

/// Builds Thread puzzles; deterministic for a given params + seed.
class ThreadGenerator {
  ThreadGenerator._();

  /// Generates a puzzle with exactly one solution.
  static ThreadPuzzle generate(ThreadParams p, int seed) {
    final n = p.size;
    if (n < 2 || n > 8) {
      throw ArgumentError.value(n, 'size', 'must be 2..8');
    }
    final cells = n * n;
    final rng = Random(seed);
    final path = randomHamiltonianPath(n, n, rng);
    // marked[i] == true: the cell at path index i carries a number.
    final marked = List<bool>.filled(cells, false);
    marked[0] = true;
    marked[cells - 1] = true;

    // Each round marks at least one more index, so this ends after < cells rounds
    // (a fully numbered board is trivially unique).
    for (var round = 0; round < cells; round++) {
      final r = ThreadSolver.findOther(n, _numbersFor(path, marked), path);
      if (r.unique) break;
      final other = r.alternative;
      if (other == null || !_markKiller(path, other, marked)) {
        // Too hard to settle within the node budget (or no single fix): split the
        // longest unnumbered stretch, which shrinks the search for the next round.
        _markLongestGap(marked);
      }
    }
    _dropRedundant(n, path, marked);
    for (var i = 0; i < p.extraNumbers; i++) {
      if (!_markLongestGap(marked)) break;
    }
    return ThreadPuzzle(
      size: n,
      numbers: _numbersFor(path, marked),
      solution: path,
    );
  }

  /// Node budget for the whole clean-up pass and for one removal attempt.
  static const int _dropBudget = 100000, _dropTryLimit = 20000;

  /// Removes numbers that later additions made unnecessary, most crowded first, while
  /// the solver still proves uniqueness. Fixes are chosen one alternative at a time,
  /// so early ones are often redundant; dropping them gives fewer, better spread
  /// numbers (harder puzzles). Bounded by node counts, so it stays deterministic.
  static void _dropRedundant(int n, List<int> path, List<bool> marked) {
    final cells = path.length;
    final tried = List<bool>.filled(cells, false);
    var budget = _dropBudget;
    while (budget > 0) {
      // Most crowded untried interior number: smallest distance between its neighbours.
      var best = -1, bestSpan = cells + 1, prev = 0;
      for (var i = 1; i < cells - 1; i++) {
        if (!marked[i]) continue;
        var next = i + 1;
        while (!marked[next]) {
          next++;
        }
        if (!tried[i] && next - prev < bestSpan) {
          best = i;
          bestSpan = next - prev;
        }
        prev = i;
      }
      if (best < 0) return;
      tried[best] = true;
      marked[best] = false;
      final r = ThreadSolver.findOther(
        n,
        _numbersFor(path, marked),
        path,
        nodeLimit: budget < _dropTryLimit ? budget : _dropTryLimit,
      );
      budget -= r.nodes;
      if (!r.unique) marked[best] = true;
    }
  }

  /// Numbers 1..K in path order for the marked indices.
  static Map<int, int> _numbersFor(List<int> path, List<bool> marked) {
    final numbers = <int, int>{};
    var k = 0;
    for (var i = 0; i < path.length; i++) {
      if (marked[i]) numbers[path[i]] = ++k;
    }
    return numbers;
  }

  /// Marks numbers that make [other] invalid; false when nothing could be marked.
  ///
  /// Adding one number kills [other] when [other] visits that cell outside the stretch
  /// between the numbers around it on the intended path. Among such cells we take the
  /// one nearest to where the paths first part (that is where the ambiguity lives).
  /// When no single cell works (e.g. only the two ends are numbered, so every cell is
  /// "between" them in both paths), two numbers are needed: the cell where the paths
  /// part and the cell [other] went to instead, which the two paths visit in opposite
  /// orders.
  static bool _markKiller(List<int> path, List<int> other, List<bool> marked) {
    final cells = path.length;
    final otherPos = Int32List(cells);
    for (var i = 0; i < cells; i++) {
      otherPos[other[i]] = i;
    }
    var split = 0;
    while (split < cells && path[split] == other[split]) {
      split++;
    }
    if (split == cells) return false;

    final prev = Int32List(cells), next = Int32List(cells);
    for (var i = 0, last = 0; i < cells; i++) {
      if (marked[i]) last = i;
      prev[i] = last;
    }
    for (var i = cells - 1, last = cells - 1; i >= 0; i--) {
      if (marked[i]) last = i;
      next[i] = last;
    }
    var best = -1, bestDist = cells + 1;
    for (var t = 0; t < cells; t++) {
      if (marked[t]) continue;
      final at = otherPos[path[t]];
      final outside =
          at < otherPos[path[prev[t]]] || at > otherPos[path[next[t]]];
      final dist = (t - split).abs();
      if (outside && dist < bestDist) {
        best = t;
        bestDist = dist;
      }
    }
    if (best >= 0) {
      marked[best] = true;
      return true;
    }
    final went = path.indexOf(other[split]);
    var changed = false;
    for (final t in [split, went]) {
      if (t >= 0 && !marked[t]) {
        marked[t] = true;
        changed = true;
      }
    }
    return changed;
  }

  /// Marks the middle of the longest run of unnumbered path cells; false when every
  /// cell already has a number.
  static bool _markLongestGap(List<bool> marked) {
    var bestFrom = -1, bestLen = 1, last = 0;
    for (var i = 1; i < marked.length; i++) {
      if (!marked[i]) continue;
      if (i - last > bestLen) {
        bestLen = i - last;
        bestFrom = last;
      }
      last = i;
    }
    if (bestFrom < 0) return false;
    marked[bestFrom + bestLen ~/ 2] = true;
    return true;
  }
}
