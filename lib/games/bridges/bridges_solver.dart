// Bridges solver: counts the ways to bridge a layout (up to a cap) with a deterministic
// node limit.
//
// Why: every generated puzzle must have exactly one solution; the generator keeps
// repairing a layout until this search proves there is no second one.
//
// Model: one variable per visible island pair (see `BridgesGraph`) holding an interval
// [lo, hi] ⊆ 0..2 of possible bridge counts. Propagation until a fixed point:
//  * degree — per island, the pairs' lows may not exceed its number, the highs must
//    reach it, and each pair is squeezed by what the island's other pairs can still
//    give or must already take (this settles most islands without any guessing);
//  * crossing — a pair with a bridge forces every pair crossing it to zero;
//  * connectivity — the pairs still possible must join all islands, and a pair that is
//    a cut-edge of that graph needs at least one bridge (so a group can never be closed
//    off early).
// What is left is branched on: the island with the fewest undecided pairs, trying each
// count of its first undecided pair. A complete assignment has full degrees and, by the
// connectivity step, one group, so it is a solution. The limit is a node count, never a
// clock, so results are identical on every device. State is copied per node (a few
// dozen bytes), which keeps backtracking trivially correct.

import 'dart:typed_data';

import 'package:focus_and_play_mindgame/games/bridges/bridges_graph.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges_puzzle.dart';

/// Result of [BridgesSolver.search].
class BridgesSearch {
  /// Creates a result.
  const BridgesSearch({
    this.count = 0,
    this.limitHit = false,
    this.nodes = 0,
    this.first,
  });

  /// Solutions found (at most the requested limit).
  final int count;

  /// True when the node limit stopped the search: uniqueness is then *not* proven.
  final bool limitHit;

  /// Search nodes spent (for tuning and tests).
  final int nodes;

  /// The first solution found, sorted by `(a, b)`; null when there is none.
  final List<BridgesLink>? first;

  /// True when the search finished and found exactly one solution.
  bool get unique => count == 1 && !limitHit;
}

/// Result of [BridgesSolver.findOther].
class BridgesOtherResult {
  /// Creates a result.
  const BridgesOtherResult({
    this.alternative,
    this.limitHit = false,
    this.nodes = 0,
  });

  /// A solution that differs from the intended one, or null when none was found.
  final List<BridgesLink>? alternative;

  /// True when the node limit stopped the search: uniqueness is then *not* proven.
  final bool limitHit;

  /// Search nodes spent.
  final int nodes;

  /// True when the search finished and found no other solution.
  bool get unique => alternative == null && !limitHit;
}

/// Exhaustive, node-limited search over Bridges solutions.
class BridgesSolver {
  BridgesSolver._();

  /// Default node budget: far above what real puzzles need, so it only guards against
  /// a pathological layout.
  static const int defaultNodeLimit = 200000;

  /// Counts the solutions of [p] (islands and needs only; `p.solution` is ignored) up
  /// to [limit]. When [nodeLimit] runs out the answer is [limit] — "not proven unique"
  /// — so callers asking `== 1` stay safe. Use [search] to tell the two apart.
  static int countSolutions(
    BridgesPuzzle p, {
    int limit = 2,
    int nodeLimit = defaultNodeLimit,
  }) {
    final r = search(p, limit: limit, nodeLimit: nodeLimit);
    return r.limitHit ? limit : r.count;
  }

  /// [countSolutions] with the details: whether the limit was hit, the nodes spent and
  /// the first solution.
  static BridgesSearch search(
    BridgesPuzzle p, {
    int limit = 2,
    int nodeLimit = defaultNodeLimit,
  }) {
    var count = 0;
    List<BridgesLink>? first;
    final g = p.graph;
    final s = _Search(p, nodeLimit, null, (lo) {
      first ??= _linksOf(g, lo);
      return ++count >= limit;
    });
    s.run();
    return BridgesSearch(
      count: count,
      limitHit: s.aborted,
      nodes: s.nodes,
      first: first,
    );
  }

  /// One solution of [p], or null when it has none (or [nodeLimit] runs out first).
  static List<BridgesLink>? solve(
    BridgesPuzzle p, {
    int nodeLimit = defaultNodeLimit,
  }) => search(p, limit: 1, nodeLimit: nodeLimit).first;

  /// Looks for a solution of [p] that differs from `p.solution`. The intended answer is
  /// tried first, so the search meets it at once and then backtracks from its end —
  /// alternatives that differ locally are found cheaply.
  static BridgesOtherResult findOther(
    BridgesPuzzle p, {
    int nodeLimit = defaultNodeLimit,
  }) {
    final g = p.graph;
    final intended = Uint8List(g.pairs.length);
    for (final l in p.solution) {
      final id = g.pairId(l.a, l.b);
      if (id >= 0) intended[id] = l.count;
    }
    List<BridgesLink>? other;
    final s = _Search(p, nodeLimit, intended, (lo) {
      for (var i = 0; i < lo.length; i++) {
        if (lo[i] != intended[i]) {
          other = _linksOf(g, lo);
          return true;
        }
      }
      return false;
    });
    s.run();
    return BridgesOtherResult(
      alternative: other,
      limitHit: s.aborted,
      nodes: s.nodes,
    );
  }
}

/// The links of a complete assignment, sorted by `(a, b)` (pairs are already in that
/// order).
List<BridgesLink> _linksOf(BridgesGraph g, Uint8List counts) => [
  for (var q = 0; q < g.pairs.length; q++)
    if (counts[q] > 0) BridgesLink(g.pairA[q], g.pairB[q], counts[q]),
];

/// Search state: per-pair bounds are passed down as `lo`/`hi` arrays; everything else
/// is scratch space shared by all nodes.
class _Search {
  _Search(BridgesPuzzle p, this.nodeLimit, this.prefer, this.onSolution)
    : g = p.graph,
      n = p.islands.length,
      pc = p.graph.pairs.length,
      need = Int32List.fromList([for (final i in p.islands) i.need]) {
    _stack = Int32List(n);
    _inStack = Uint8List(n);
  }

  final BridgesGraph g;
  final int n, pc, nodeLimit;
  final Int32List need;

  /// Intended count per pair; tried first when set.
  final Uint8List? prefer;

  /// Called with each solution (counts per pair); returns true to stop the search.
  final bool Function(Uint8List counts) onSolution;

  late final Int32List _stack;
  late final Uint8List _inStack;
  late final BridgesCutFinder _cuts = BridgesCutFinder(g);
  int _sp = 0;

  int nodes = 0;
  bool aborted = false;
  bool _stop = false;

  void run() {
    if (n == 0) return;
    final lo = Uint8List(pc), hi = Uint8List(pc);
    for (var q = 0; q < pc; q++) {
      final m = need[g.pairA[q]] < need[g.pairB[q]]
          ? need[g.pairA[q]]
          : need[g.pairB[q]];
      hi[q] = m > 2 ? 2 : (m < 0 ? 0 : m);
    }
    for (var i = 0; i < n; i++) {
      _push(i);
    }
    if (_propagate(lo, hi)) _dfs(lo, hi);
  }

  void _push(int i) {
    if (_inStack[i] != 0) return;
    _inStack[i] = 1;
    _stack[_sp++] = i;
  }

  void _clear() {
    while (_sp > 0) {
      _inStack[_stack[--_sp]] = 0;
    }
  }

  /// Raises the lower bound of pair [q] to [v]; false on a conflict.
  bool _raise(Uint8List lo, Uint8List hi, int q, int v) {
    if (v > hi[q]) return false;
    if (v <= lo[q]) return true;
    final wasZero = lo[q] == 0;
    lo[q] = v;
    _push(g.pairA[q]);
    _push(g.pairB[q]);
    if (wasZero) {
      for (final x in g.crossers[q]) {
        if (lo[x] > 0) return false;
        if (hi[x] > 0) {
          hi[x] = 0;
          _push(g.pairA[x]);
          _push(g.pairB[x]);
        }
      }
    }
    return true;
  }

  /// Lowers the upper bound of pair [q] to [v]; false on a conflict.
  bool _lower(Uint8List lo, Uint8List hi, int q, int v) {
    if (v < lo[q]) return false;
    if (v >= hi[q]) return true;
    hi[q] = v;
    _push(g.pairA[q]);
    _push(g.pairB[q]);
    return true;
  }

  /// Runs the rules to a fixed point; false when the bounds became contradictory.
  /// Islands to look at are taken from the stack.
  bool _propagate(Uint8List lo, Uint8List hi) {
    while (true) {
      while (_sp > 0) {
        final i = _stack[--_sp];
        _inStack[i] = 0;
        final inc = g.incident[i];
        var sl = 0, sh = 0;
        for (final q in inc) {
          sl += lo[q];
          sh += hi[q];
        }
        final nd = need[i];
        if (sl > nd || sh < nd) {
          _clear();
          return false;
        }
        if (sl == sh) continue;
        for (final q in inc) {
          final l = lo[q], h = hi[q];
          if (l == h) continue;
          // What the island's other pairs can still give / must already take.
          final nl = nd - (sh - h), nh = nd - (sl - l);
          if (nl > l && !_raise(lo, hi, q, nl) ||
              nh < h && !_lower(lo, hi, q, nh)) {
            _clear();
            return false;
          }
        }
      }
      final c = _connectivity(lo, hi);
      if (c < 0) return false;
      if (c == 0) return true;
    }
  }

  /// Checks that the possible pairs join all islands and forces a bridge on every
  /// cut-edge. Returns -1 on failure, 1 when it raised something (rules must run
  /// again), 0 when nothing changed.
  int _connectivity(Uint8List lo, Uint8List hi) {
    if (!_cuts.find(hi)) return -1;
    var changed = 0;
    for (var k = 0; k < _cuts.cutCount; k++) {
      final q = _cuts.cuts[k];
      if (lo[q] != 0) continue;
      if (!_raise(lo, hi, q, 1)) {
        _clear();
        return -1;
      }
      changed = 1;
    }
    return changed;
  }

  void _dfs(Uint8List lo, Uint8List hi) {
    if (++nodes > nodeLimit) {
      aborted = true;
      _stop = true;
      return;
    }
    // The island with the fewest undecided pairs; its first undecided pair is split.
    var best = -1, bestOpen = 1 << 30;
    for (var i = 0; i < n; i++) {
      var open = 0;
      for (final q in g.incident[i]) {
        if (lo[q] != hi[q]) open++;
      }
      if (open > 0 && open < bestOpen) {
        best = i;
        bestOpen = open;
        if (open == 1) break;
      }
    }
    if (best < 0) {
      if (onSolution(lo)) _stop = true;
      return;
    }
    var q = -1;
    for (final x in g.incident[best]) {
      if (lo[x] != hi[x]) {
        q = x;
        break;
      }
    }
    final l = lo[q], h = hi[q];
    final first = prefer == null ? -1 : prefer![q];
    for (var k = -1; k <= h; k++) {
      // Intended count first (when set), then ascending without repeating it.
      final v = k < 0 ? first : k;
      if (v < l || v > h || (k >= 0 && v == first)) continue;
      final lo2 = Uint8List.fromList(lo), hi2 = Uint8List.fromList(hi);
      if (_raise(lo2, hi2, q, v) &&
          _lower(lo2, hi2, q, v) &&
          _propagate(lo2, hi2)) {
        _dfs(lo2, hi2);
        if (_stop) return;
      } else {
        _clear();
      }
    }
  }
}
