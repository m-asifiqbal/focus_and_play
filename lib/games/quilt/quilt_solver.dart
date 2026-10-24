// Quilt solver: exact cover of the grid by candidate rectangles, counting solutions up
// to a cap with a deterministic node limit.
//
// Why exact cover: a candidate for a clue is any in-grid rectangle that holds that clue
// and no other and matches its area/shape — exactly what `QuiltRules.fits` accepts — so
// a solution is a set of candidates covering every cell once. (Each clue cell can only
// be covered by its own clue's candidates, so every clue is then used exactly once.)
// The search always branches on the uncovered cell with the fewest live candidates,
// kept up to date incrementally, which settles real boards in a few hundred nodes.

import 'dart:typed_data';

import 'package:focus_and_play_mindgame/games/quilt/quilt_puzzle.dart';

/// Result of [QuiltSolver.findOther].
class QuiltSearchResult {
  /// Creates a result.
  const QuiltSearchResult({
    this.alternative,
    this.limitHit = false,
    this.nodes = 0,
  });

  /// A solution (one rectangle per clue, in clue order) that differs from the intended
  /// one, or null when none was found.
  final List<QuiltRect>? alternative;

  /// True when the node limit stopped the search: uniqueness is then *not* proven.
  final bool limitHit;

  /// Search nodes spent (for tuning and tests).
  final int nodes;

  /// True when the search finished and found no other solution.
  bool get unique => alternative == null && !limitHit;
}

/// Exhaustive, node-limited search over Quilt solutions.
class QuiltSolver {
  QuiltSolver._();

  /// Default node budget; unique boards need far fewer.
  static const int defaultNodeLimit = 50000;

  /// Every rectangle that could be the patch of `clues[index]` under the rules: inside
  /// the [size]×[size] grid, holding that clue cell and no other, with the clue's
  /// area and shape. Shape-only clues are not capped by any area (the player isn't told
  /// one). Deterministic order.
  static List<QuiltRect> candidatesFor(
    int size,
    List<QuiltClue> clues,
    int index,
  ) => _Candidates(size, clues).forClue(index);

  /// Counts solutions up to [maxSolutions]; null when [nodeLimit] nodes were spent
  /// first.
  static int? countSolutions(
    int size,
    List<QuiltClue> clues, {
    int maxSolutions = 2,
    int nodeLimit = defaultNodeLimit,
  }) {
    var count = 0;
    final s = _Search(size, clues, nodeLimit, null, (_) {
      return ++count >= maxSolutions;
    });
    s.run();
    return s.aborted ? null : count;
  }

  /// Looks for a solution that differs from [intended] (`intended[i]` is the patch of
  /// `clues[i]`).
  static QuiltSearchResult findOther(
    int size,
    List<QuiltClue> clues,
    List<QuiltRect> intended, {
    int nodeLimit = defaultNodeLimit,
  }) {
    List<QuiltRect>? other;
    final s = _Search(size, clues, nodeLimit, intended, (rects) {
      for (var i = 0; i < rects.length; i++) {
        if (rects[i] != intended[i]) {
          other = List<QuiltRect>.of(rects);
          return true;
        }
      }
      return false;
    });
    s.run();
    return QuiltSearchResult(
      alternative: other,
      limitHit: s.aborted,
      nodes: s.nodes,
    );
  }
}

/// Candidate enumeration with an O(1) "how many clues inside" test (2D prefix sums).
class _Candidates {
  _Candidates(this.n, this.clues) : _pre = Int32List((n + 1) * (n + 1)) {
    final grid = Int32List(n * n);
    for (final c in clues) {
      if (c.cell >= 0 && c.cell < n * n) grid[c.cell]++;
    }
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        _pre[(r + 1) * (n + 1) + c + 1] =
            grid[r * n + c] +
            _pre[r * (n + 1) + c + 1] +
            _pre[(r + 1) * (n + 1) + c] -
            _pre[r * (n + 1) + c];
      }
    }
  }

  final int n;
  final List<QuiltClue> clues;
  final Int32List _pre;

  int _cluesIn(int row, int col, int w, int h) {
    final s = n + 1;
    return _pre[(row + h) * s + col + w] -
        _pre[row * s + col + w] -
        _pre[(row + h) * s + col] +
        _pre[row * s + col];
  }

  List<QuiltRect> forClue(int index) {
    final clue = clues[index];
    final out = <QuiltRect>[];
    if (clue.cell < 0 || clue.cell >= n * n) return out;
    final cr = clue.cell ~/ n, cc = clue.cell % n;
    for (var h = 1; h <= n; h++) {
      for (var w = 1; w <= n; w++) {
        final a = clue.area;
        if (a != null && w * h != a) continue;
        final shape = clue.shape;
        if (shape != null && QuiltShape.of(w, h) != shape) continue;
        final r0 = cr - h + 1 < 0 ? 0 : cr - h + 1;
        final r1 = cr < n - h ? cr : n - h;
        final c0 = cc - w + 1 < 0 ? 0 : cc - w + 1;
        final c1 = cc < n - w ? cc : n - w;
        for (var r = r0; r <= r1; r++) {
          for (var c = c0; c <= c1; c++) {
            if (_cluesIn(r, c, w, h) == 1) {
              out.add(QuiltRect(row: r, col: c, width: w, height: h));
            }
          }
        }
      }
    }
    return out;
  }
}

/// Exact-cover search state.
class _Search {
  _Search(
    this.n,
    List<QuiltClue> clues,
    this.nodeLimit,
    List<QuiltRect>? prefer,
    this.onSolution,
  ) : cells = n * n,
      clueCount = clues.length {
    final gen = _Candidates(n, clues);
    final perCell = List<List<int>>.generate(cells, (_) => <int>[]);
    final rectCells = <Int32List>[];
    final preferred = <int>[];
    for (var i = 0; i < clues.length; i++) {
      for (final r in gen.forClue(i)) {
        final id = rects.length;
        rects.add(r);
        owner.add(i);
        if (prefer != null && prefer[i] == r) preferred.add(id);
        final cs = Int32List.fromList(r.cells(n).toList());
        rectCells.add(cs);
        for (final c in cs) {
          perCell[c].add(id);
        }
      }
    }
    // Trying the intended patches first makes the search meet the intended solution
    // at once and then backtrack from its end, so "other" solutions that differ late
    // are found cheaply. The order never changes the count.
    for (final p in preferred) {
      for (final c in rectCells[p]) {
        final l = perCell[c];
        l.remove(p);
        l.insert(0, p);
      }
    }
    this.rectCells = rectCells;
    cellCands = [for (final l in perCell) Int32List.fromList(l)];
    blocked = Int32List(rects.length);
    live = Int32List(cells);
    for (var c = 0; c < cells; c++) {
      live[c] = cellCands[c].length;
    }
    covered = Uint8List(cells);
    chosen = List<QuiltRect>.filled(clueCount, _none);
  }

  static const _none = QuiltRect(row: 0, col: 0, width: 0, height: 0);

  final int n, cells, clueCount, nodeLimit;

  /// Called with each solution (patch per clue); returns true to stop the search.
  final bool Function(List<QuiltRect> rects) onSolution;

  final rects = <QuiltRect>[];
  final owner = <int>[]; // candidate → clue index
  late final List<Int32List> rectCells; // candidate → its cells
  late final List<Int32List> cellCands; // cell → candidates covering it
  late final Int32List
  blocked; // candidate → covered cells inside it (0 = live)
  late final Int32List live; // cell → live candidates covering it
  late final Uint8List covered;
  late final List<QuiltRect> chosen;

  int nodes = 0;
  bool aborted = false;
  bool _stop = false;

  void run() {
    if (clueCount == 0) return;
    _dfs(0);
  }

  void _place(int d) {
    for (final c in rectCells[d]) {
      covered[c] = 1;
      for (final e in cellCands[c]) {
        if (blocked[e]++ == 0) {
          for (final c2 in rectCells[e]) {
            live[c2]--;
          }
        }
      }
    }
  }

  void _unplace(int d) {
    for (final c in rectCells[d]) {
      covered[c] = 0;
      for (final e in cellCands[c]) {
        if (--blocked[e] == 0) {
          for (final c2 in rectCells[e]) {
            live[c2]++;
          }
        }
      }
    }
  }

  void _dfs(int coveredCount) {
    if (coveredCount == cells) {
      if (onSolution(chosen)) _stop = true;
      return;
    }
    if (++nodes > nodeLimit) {
      aborted = true;
      _stop = true;
      return;
    }
    var best = -1, bestLive = 1 << 30;
    for (var c = 0; c < cells; c++) {
      if (covered[c] != 0) continue;
      final l = live[c];
      if (l < bestLive) {
        if (l == 0) return; // this cell can no longer be covered
        best = c;
        bestLive = l;
      }
    }
    for (final d in cellCands[best]) {
      if (blocked[d] != 0) continue;
      _place(d);
      chosen[owner[d]] = rects[d];
      _dfs(coveredCount + rectCells[d].length);
      _unplace(d);
      if (_stop) return;
    }
  }
}
