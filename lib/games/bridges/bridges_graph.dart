// Bridges geometry: which islands see each other and which candidate bridges cross.
//
// Why a separate, cached structure: the rules (called on every tap), the hint
// reasoner and the solver all work on the same "pair graph" — one node per visible
// island pair — so it is built once per puzzle from the island coordinates and shared.
// It only needs integers (island rows/cols), so it has no dependency on the model
// classes. Pure Dart (no Flutter imports).

import 'dart:typed_data';

/// The pair graph of a Bridges layout: visible pairs, the pairs at each island and the
/// pairs that would cross each other.
class BridgesGraph {
  BridgesGraph._(
    this.islandCount,
    this.rows,
    this.cols,
    this.pairs,
    this.pairA,
    this.pairB,
    this.incident,
    this.crossers,
    this._ids,
    this.cellIsland,
  );

  /// Builds the graph for islands at ([islandRow], [islandCol]) in a [rows]×[cols]
  /// grid. Islands must be in row-major order (that is what makes pairs come out sorted
  /// by `(a, b)`).
  factory BridgesGraph.build(
    int rows,
    int cols,
    List<int> islandRow,
    List<int> islandCol,
  ) {
    final n = islandRow.length;
    final cellIsland = Int32List(rows * cols)..fillRange(0, rows * cols, -1);
    for (var i = 0; i < n; i++) {
      cellIsland[islandRow[i] * cols + islandCol[i]] = i;
    }
    final pairs = <(int, int)>[];
    final aList = <int>[], bList = <int>[];
    final inc = List<List<int>>.generate(n, (_) => <int>[]);
    final ids = Int32List(n * n)..fillRange(0, n * n, -1);
    void add(int a, int b) {
      ids[a * n + b] = pairs.length;
      inc[a].add(pairs.length);
      inc[b].add(pairs.length);
      pairs.add((a, b));
      aList.add(a);
      bList.add(b);
    }

    // Per island: the first island to the right, then the first one below. A right
    // neighbour always has a smaller index than a lower one, so this is already the
    // (a, b) order.
    for (var a = 0; a < n; a++) {
      final r = islandRow[a], c = islandCol[a];
      for (var x = c + 1; x < cols; x++) {
        final b = cellIsland[r * cols + x];
        if (b >= 0) {
          add(a, b);
          break;
        }
      }
      for (var y = r + 1; y < rows; y++) {
        final b = cellIsland[y * cols + c];
        if (b >= 0) {
          add(a, b);
          break;
        }
      }
    }
    // A horizontal and a vertical pair cross when each one's line passes strictly
    // inside the other's span. Parallel pairs never cross (islands block the line).
    final count = pairs.length;
    final horizontal = <int>[], vertical = <int>[];
    for (var p = 0; p < count; p++) {
      (islandRow[aList[p]] == islandRow[bList[p]] ? horizontal : vertical).add(
        p,
      );
    }
    final cross = List<List<int>>.generate(count, (_) => <int>[]);
    for (final h in horizontal) {
      final row = islandRow[aList[h]];
      final c1 = islandCol[aList[h]], c2 = islandCol[bList[h]];
      for (final v in vertical) {
        final col = islandCol[aList[v]];
        if (col <= c1 || col >= c2) continue;
        if (row > islandRow[aList[v]] && row < islandRow[bList[v]]) {
          cross[h].add(v);
          cross[v].add(h);
        }
      }
    }
    return BridgesGraph._(
      n,
      rows,
      cols,
      List.unmodifiable(pairs),
      Int32List.fromList(aList),
      Int32List.fromList(bList),
      [for (final l in inc) Int32List.fromList(l)],
      [for (final l in cross) Int32List.fromList(l..sort())],
      ids,
      cellIsland,
    );
  }

  /// Number of islands.
  final int islandCount;

  /// Grid size.
  final int rows, cols;

  /// Every visible pair `(a, b)` with `a < b`, ordered by `(a, b)`.
  final List<(int, int)> pairs;

  /// Island indices of pair `p` (`pairA[p] < pairB[p]`).
  final Int32List pairA, pairB;

  /// For each island, the ids (indices into [pairs]) of the pairs it belongs to.
  final List<Int32List> incident;

  /// For each pair, the ids of the pairs whose bridges would cross it.
  final List<Int32List> crossers;

  /// Island index of each grid cell, or -1.
  final Int32List cellIsland;

  final Int32List _ids;

  /// Id of the visible pair `(a, b)` (either order), or -1 when they do not see each
  /// other or an index is out of range.
  int pairId(int a, int b) {
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    if (a < 0 || b >= islandCount || a == b) return -1;
    return _ids[a * islandCount + b];
  }
}

/// Finds the cut-edges of "the graph of pairs that can still carry a bridge": a pair
/// whose removal splits the islands must carry at least one bridge, and if the graph
/// is already split there is no solution. Keeps its scratch arrays, so it can be
/// called once per search node without allocating.
class BridgesCutFinder {
  /// Creates a finder for [g].
  BridgesCutFinder(this.g)
    : _disc = Int32List(g.islandCount),
      _low = Int32List(g.islandCount),
      cuts = Int32List(g.pairs.length);

  /// The graph searched.
  final BridgesGraph g;

  /// Pair ids of the cut-edges found by the last [find]: `cuts[0..cutCount)`.
  final Int32List cuts;

  /// How many entries of [cuts] are valid.
  int cutCount = 0;

  final Int32List _disc, _low;
  int _timer = 0;

  /// Searches the graph of pairs with `hi[q] > 0`. Returns false when it does not
  /// connect all islands; otherwise fills [cuts].
  bool find(Uint8List hi) {
    final n = g.islandCount;
    _disc.fillRange(0, n, 0);
    _timer = 0;
    cutCount = 0;
    if (n == 0) return true;
    _visit(0, -1, hi);
    return _timer == n;
  }

  void _visit(int u, int via, Uint8List hi) {
    _disc[u] = _low[u] = ++_timer;
    for (final q in g.incident[u]) {
      if (hi[q] == 0 || q == via) continue;
      final w = g.pairA[q] == u ? g.pairB[q] : g.pairA[q];
      if (_disc[w] == 0) {
        _visit(w, q, hi);
        if (_low[w] < _low[u]) _low[u] = _low[w];
        if (_low[w] > _disc[u]) cuts[cutCount++] = q;
      } else if (_disc[w] < _low[u]) {
        _low[u] = _disc[w];
      }
    }
  }
}
