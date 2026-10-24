// Bridges puzzle model: numbered islands on a grid, the bridges that solve it, and the
// generation settings.
//
// The player joins islands with straight bridges (at most two per pair, never crossing
// another bridge) so every island has exactly as many bridges as its number and all
// islands end up in one group. Links refer to islands by index, so a puzzle is two small
// lists plus the grid size.
//
// Why plain data + JSON: the generator runs inside `Isolate.run`, and the app saves and
// restores games, so everything here crosses isolates and survives a JSON round trip.
// Pure Dart (no Flutter imports).

import 'package:focus_and_play_mindgame/games/bridges/bridges_graph.dart';

/// A numbered island: its cell ([row], [col]) and how many bridges it needs.
class BridgesIsland {
  /// Creates an island needing [need] bridges (1..8).
  const BridgesIsland({
    required this.row,
    required this.col,
    required this.need,
  });

  /// Rebuilds an island from [toJson] output.
  factory BridgesIsland.fromJson(Map<String, Object?> j) => BridgesIsland(
    row: (j['row'] as num).toInt(),
    col: (j['col'] as num).toInt(),
    need: (j['need'] as num).toInt(),
  );

  /// Grid position.
  final int row, col;

  /// Bridges the island must end up with.
  final int need;

  /// Plain JSON.
  Map<String, Object?> toJson() => {'row': row, 'col': col, 'need': need};

  @override
  bool operator ==(Object other) =>
      other is BridgesIsland &&
      other.row == row &&
      other.col == col &&
      other.need == need;

  @override
  int get hashCode => Object.hash(row, col, need);

  @override
  String toString() => 'BridgesIsland($row, $col, need $need)';
}

/// The bridges between island [a] and island [b] (indices into
/// `BridgesPuzzle.islands`, `a < b`): [count] is 1 or 2.
class BridgesLink {
  /// Creates a link; keep `a < b` and `count` 1 or 2.
  const BridgesLink(this.a, this.b, this.count)
    : assert(a < b, 'a link is stored with a < b'),
      assert(count == 1 || count == 2, 'a link has one or two bridges');

  /// Rebuilds a link from [toJson] output.
  factory BridgesLink.fromJson(Map<String, Object?> j) => BridgesLink(
    (j['a'] as num).toInt(),
    (j['b'] as num).toInt(),
    (j['count'] as num).toInt(),
  );

  /// The two islands (indices), `a < b`.
  final int a, b;

  /// Number of bridges: 1 or 2.
  final int count;

  /// The same pair with another [count].
  BridgesLink withCount(int count) => BridgesLink(a, b, count);

  /// Plain JSON.
  Map<String, Object?> toJson() => {'a': a, 'b': b, 'count': count};

  @override
  bool operator ==(Object other) =>
      other is BridgesLink &&
      other.a == a &&
      other.b == b &&
      other.count == count;

  @override
  int get hashCode => Object.hash(a, b, count);

  @override
  String toString() => 'BridgesLink($a-$b x$count)';
}

/// A generated Bridges puzzle with its unique [solution].
class BridgesPuzzle {
  /// Creates a puzzle. [islands] are expected in row-major order and [solution] sorted
  /// by `(a, b)`; if they are not, they are sorted here (links remapped) so the
  /// invariants always hold. Throws [ArgumentError] for an island outside the grid or
  /// two islands on one cell.
  factory BridgesPuzzle({
    required int rows,
    required int cols,
    required List<BridgesIsland> islands,
    required List<BridgesLink> solution,
  }) {
    for (final i in islands) {
      if (i.row < 0 || i.col < 0 || i.row >= rows || i.col >= cols) {
        throw ArgumentError.value(i, 'islands', 'outside the $rows×$cols grid');
      }
    }
    final order = List<int>.generate(islands.length, (i) => i)
      ..sort((x, y) {
        final c = islands[x].row.compareTo(islands[y].row);
        return c != 0 ? c : islands[x].col.compareTo(islands[y].col);
      });
    final sorted = [for (final i in order) islands[i]];
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].row == sorted[i - 1].row &&
          sorted[i].col == sorted[i - 1].col) {
        throw ArgumentError.value(
          sorted[i],
          'islands',
          'two islands on a cell',
        );
      }
    }
    final newIndex = List<int>.filled(order.length, 0);
    for (var i = 0; i < order.length; i++) {
      newIndex[order[i]] = i;
    }
    final links = <BridgesLink>[];
    for (final l in solution) {
      final x = newIndex[l.a], y = newIndex[l.b];
      links.add(
        x < y ? BridgesLink(x, y, l.count) : BridgesLink(y, x, l.count),
      );
    }
    links.sort((p, q) => p.a != q.a ? p.a.compareTo(q.a) : p.b.compareTo(q.b));
    return BridgesPuzzle._(rows, cols, sorted, links);
  }

  BridgesPuzzle._(
    this.rows,
    this.cols,
    List<BridgesIsland> islands,
    List<BridgesLink> solution,
  ) : islands = List.unmodifiable(islands),
      solution = List.unmodifiable(solution),
      graph = BridgesGraph.build(
        rows,
        cols,
        [for (final i in islands) i.row],
        [for (final i in islands) i.col],
      );

  /// Rebuilds a puzzle from [toJson] output.
  factory BridgesPuzzle.fromJson(Map<String, Object?> j) => BridgesPuzzle(
    rows: (j['rows'] as num).toInt(),
    cols: (j['cols'] as num).toInt(),
    islands: [
      for (final i in j['islands'] as List)
        BridgesIsland.fromJson((i as Map).cast<String, Object?>()),
    ],
    solution: [
      for (final l in j['solution'] as List)
        BridgesLink.fromJson((l as Map).cast<String, Object?>()),
    ],
  );

  /// Grid size.
  final int rows, cols;

  /// The islands, in row-major order of their cells.
  final List<BridgesIsland> islands;

  /// The unique solution, sorted by `(a, b)`.
  final List<BridgesLink> solution;

  /// Visible pairs, crossings and per-island pairs (computed once, shared by the
  /// rules, hints and solver).
  final BridgesGraph graph;

  /// Index of the island at ([row], [col]), or null (also outside the grid).
  int? islandAt(int row, int col) {
    if (row < 0 || col < 0 || row >= rows || col >= cols) return null;
    final i = graph.cellIsland[row * cols + col];
    return i < 0 ? null : i;
  }

  /// Row-major cell index (`row * cols + col`) of island [i].
  int cellOf(int i) => islands[i].row * cols + islands[i].col;

  /// Plain JSON.
  Map<String, Object?> toJson() => {
    'rows': rows,
    'cols': cols,
    'islands': [for (final i in islands) i.toJson()],
    'solution': [for (final l in solution) l.toJson()],
  };
}

/// Generation settings for a Bridges puzzle.
class BridgesParams {
  /// Creates params. The app uses 5×5 … 9×9 with 6 … 20 islands.
  const BridgesParams({
    required this.rows,
    required this.cols,
    required this.islands,
    this.doubles = .3,
  });

  /// Grid size.
  final int rows, cols;

  /// Target number of islands. The generator may end with a few more when it needs
  /// extra islands to make the answer unique.
  final int islands;

  /// Share (0..1) of the solution's links drawn as two bridges.
  final double doubles;
}
