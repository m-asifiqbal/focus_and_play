// Thread solver: counts the paths that satisfy a set of numbers (up to a cap), with a
// deterministic node limit.
//
// Why: every generated puzzle must have exactly one solution. The generator keeps adding
// numbers until this search proves there is no second path. The search is a DFS from the
// cell with 1 with prunes that keep 8×8 boards fast:
//  * dead ends — an unvisited cell (other than the end) with a single unvisited
//    neighbour must be entered from the head right now; two such cells cannot both be;
//  * connectivity — every unvisited cell must stay reachable from the head;
//  * numbers — the next numbered cell must be reachable without stepping on any other
//    numbered cell (they all come later), and so must each later number from the one
//    before it.
// The limit is a node count, never a clock, so results are identical on every device.
// Cell sets are 64-bit bitboards, so this needs native (VM/AOT) ints — the app
// generates in `Isolate.run` — and caps the grid at 8×8.

import 'dart:typed_data';

import 'package:focus_and_play_mindgame/games/common/grid.dart';

/// Result of [ThreadSolver.findOther].
class ThreadSearchResult {
  /// Creates a result.
  const ThreadSearchResult({
    this.alternative,
    this.limitHit = false,
    this.nodes = 0,
  });

  /// Search nodes spent (for tuning and tests).
  final int nodes;

  /// A valid path that differs from the intended one, or null when none was found.
  final List<int>? alternative;

  /// True when the node limit stopped the search: uniqueness is then *not* proven.
  final bool limitHit;

  /// True when the search finished and found no other path.
  bool get unique => alternative == null && !limitHit;
}

/// Exhaustive, node-limited search over Thread paths.
class ThreadSolver {
  ThreadSolver._();

  /// Default node budget: enough to settle 8×8 boards, small enough for a phone.
  static const int defaultNodeLimit = 200000;

  /// Counts paths through the [size]×[size] grid that satisfy [numbers] (cell → number),
  /// stopping at [maxSolutions]. Returns null when [nodeLimit] nodes were spent first.
  static int? countSolutions(
    int size,
    Map<int, int> numbers, {
    int maxSolutions = 2,
    int nodeLimit = defaultNodeLimit,
  }) {
    var count = 0;
    final s = _Search(size, numbers, nodeLimit, (_) => ++count >= maxSolutions);
    s.run();
    return s.aborted ? null : count;
  }

  /// Looks for a path that satisfies [numbers] but differs from [intended].
  static ThreadSearchResult findOther(
    int size,
    Map<int, int> numbers,
    List<int> intended, {
    int nodeLimit = defaultNodeLimit,
  }) {
    List<int>? other;
    final prefer = Int32List(size * size)..fillRange(0, size * size, -1);
    for (var i = 0; i + 1 < intended.length; i++) {
      prefer[intended[i]] = intended[i + 1];
    }
    final s = _Search(size, numbers, nodeLimit, prefer: prefer, (path) {
      for (var i = 0; i < path.length; i++) {
        if (path[i] != intended[i]) {
          other = List<int>.of(path);
          return true;
        }
      }
      return false;
    });
    s.run();
    return ThreadSearchResult(
      alternative: other,
      limitHit: s.aborted,
      nodes: s.nodes,
    );
  }
}

/// The search state. Cell sets are 64-bit bitboards (n ≤ 8), which makes the flood
/// fills that dominate the run time a handful of shifts per step.
class _Search {
  _Search(
    this.n,
    Map<int, int> numbers,
    this.nodeLimit,
    this.onSolution, {
    this.prefer,
  }) : cells = n * n {
    if (n < 2 || n > 8) throw ArgumentError.value(n, 'size', 'must be 2..8');
    nbr = [for (var c = 0; c < cells; c++) neighboursOf(c, n, n)];
    nbMask = Int64List(cells);
    deg = Int32List(cells);
    for (var c = 0; c < cells; c++) {
      for (final x in nbr[c]) {
        nbMask[c] |= 1 << x;
      }
      deg[c] = nbr[c].length;
    }
    var notFirst = 0, notLast = 0;
    for (var c = 0; c < cells; c++) {
      if (c % n != 0) notFirst |= 1 << c;
      if (c % n != n - 1) notLast |= 1 << c;
    }
    notFirstCol = notFirst;
    notLastCol = notLast;
    numAt = Int32List(cells);
    var k = 0, numbered = 0;
    for (final e in numbers.entries) {
      numAt[e.key] = e.value;
      numbered |= 1 << e.key;
      if (e.value > k) k = e.value;
    }
    numberedMask = numbered;
    maxNumber = k;
    cellOfNum = Int32List(k + 2)..fillRange(0, k + 2, -1);
    for (final e in numbers.entries) {
      cellOfNum[e.value] = e.key;
    }
    free = cells == 64 ? -1 : (1 << cells) - 1;
    path = Int32List(cells);
    forced = Int32List(cells + 1);
  }

  final int n;
  final int cells;
  final int nodeLimit;

  /// Next cell of the intended path per cell (-1 at its end); tried first when set.
  final Int32List? prefer;

  /// Called with each solution; returns true to stop the search.
  final bool Function(Int32List path) onSolution;

  late final List<List<int>> nbr;
  late final Int64List nbMask; // neighbours of each cell as a bitboard
  late final int notFirstCol, notLastCol, numberedMask;
  late final Int32List numAt; // 0 = no number
  late final Int32List cellOfNum; // number → cell, -1 when missing
  late final int maxNumber;
  late final Int32List deg; // unvisited neighbours of each cell
  late final Int32List path;
  late final Int32List forced; // forced next cell per depth, -1 = free choice
  int free = 0; // unvisited cells
  int endCell = -1;

  int nodes = 0;
  bool aborted = false;
  bool _stop = false;

  void run() {
    if (maxNumber < 2) return; // needs a distinct start and end
    for (var v = 1; v <= maxNumber; v++) {
      if (cellOfNum[v] < 0) return; // numbers must be 1..K without gaps
    }
    final start = cellOfNum[1];
    endCell = cellOfNum[maxNumber];
    _visit(start);
    path[0] = start;
    if (_feasible(start, 1, 2)) _dfs(start, 1, 2);
  }

  void _visit(int c) {
    free &= ~(1 << c);
    for (final x in nbr[c]) {
      deg[x]--;
    }
  }

  void _unvisit(int c) {
    free |= 1 << c;
    for (final x in nbr[c]) {
      deg[x]++;
    }
  }

  void _dfs(int head, int depth, int nextNum) {
    if (depth == cells) {
      if (onSolution(path)) _stop = true;
      return;
    }
    if (++nodes > nodeLimit) {
      aborted = true;
      _stop = true;
      return;
    }
    final f = forced[depth];
    if (f >= 0) {
      _step(f, depth, nextNum);
      return;
    }
    // Following the intended path first means the search backtracks from its end, so
    // the first "other" path found is a late, local detour — cheap to find and to fix.
    final p = prefer == null ? -1 : prefer![head];
    if (p >= 0) {
      _step(p, depth, nextNum);
      if (_stop) return;
    }
    for (final w in nbr[head]) {
      if (w == p) continue;
      _step(w, depth, nextNum);
      if (_stop) return;
    }
  }

  /// Tries moving the head to [w] as cell number [depth] of the path.
  void _step(int w, int depth, int nextNum) {
    if (free & (1 << w) == 0) return;
    var nn = nextNum;
    final num = numAt[w];
    if (num != 0) {
      if (num != nextNum) return;
      nn++;
    }
    if (w == endCell && depth != cells - 1) return;
    _visit(w);
    path[depth] = w;
    if (_feasible(w, depth + 1, nn)) _dfs(w, depth + 1, nn);
    _unvisit(w);
  }

  /// Checks the state after the head moved to [v] ([depth] cells visited) and records
  /// the forced next move. Only [v]'s neighbours can have become dead ends: any earlier
  /// one was adjacent to the previous head and therefore forced to be [v].
  bool _feasible(int v, int depth, int nextNum) {
    final remaining = cells - depth;
    if (remaining == 0) return true;
    var f = -1;
    for (final x in nbr[v]) {
      if (free & (1 << x) == 0) continue;
      final d = deg[x];
      if (x == endCell) {
        // The end needs a way in from another unvisited cell unless it is the last one.
        if (d == 0 && remaining > 1) return false;
        continue;
      }
      if (d == 0) return false;
      if (d == 1) {
        if (f >= 0) return false;
        f = x;
      }
    }
    if (f >= 0 && numAt[f] != 0 && numAt[f] != nextNum) return false;
    forced[depth] = f;
    return _reachable(v, nextNum);
  }

  /// Cells of [b] plus their edge neighbours (may spill outside the board; callers mask).
  int _grow(int b) =>
      b |
      (b >>> n) |
      (b << n) |
      ((b >>> 1) & notLastCol) |
      ((b << 1) & notFirstCol);

  /// Everything reachable from [seed] while staying inside [within].
  int _flood(int seed, int within) {
    var r = seed & within;
    while (true) {
      final g = _grow(r) & within;
      if (g == r) return r;
      r = g;
    }
  }

  /// From the head [v]: the next numbered cell must be reachable over unnumbered cells
  /// (every other numbered cell comes later), every unvisited cell must be reachable
  /// at all, and each later pair of consecutive numbers must be joinable over
  /// unnumbered cells too. The pair checks cost a few floods per node but cut the
  /// tree by more than half on sparse 8×8 boards.
  bool _reachable(int v, int nextNum) {
    final around = nbMask[v] & free;
    final plainCells = free & ~numberedMask;
    final plain = _flood(around, plainCells);
    if ((_grow(plain) | around) & (1 << cellOfNum[nextNum]) == 0) return false;
    if (_flood(plain | around, free) != free) return false;
    for (var j = nextNum; j < maxNumber; j++) {
      final a = cellOfNum[j], b = 1 << cellOfNum[j + 1];
      if (nbMask[a] & b != 0) continue;
      final between = _flood(nbMask[a] & plainCells, plainCells);
      if (_grow(between) & b == 0) return false;
    }
    return true;
  }
}
