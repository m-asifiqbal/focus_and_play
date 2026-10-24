// Thread puzzle model: one path through every cell of an n×n grid that passes the
// numbered cells in order 1→K (1 is the start, K the end).
//
// Why plain data + JSON: the generator runs inside `Isolate.run`, and the app saves and
// restores games, so the puzzle must cross isolates and survive a round trip through JSON.
// Pure Dart (no Flutter imports).

/// A generated Thread puzzle and its (unique) solution.
class ThreadPuzzle {
  /// Builds a puzzle. [numbers] maps cell → number and must hold 1..K exactly once each.
  ThreadPuzzle({
    required this.size,
    required Map<int, int> numbers,
    required List<int> solution,
  }) : numbers = Map.unmodifiable(_inNumberOrder(numbers)),
       solution = List.unmodifiable(solution),
       maxNumber = numbers.values.fold(0, (a, b) => a > b ? a : b);

  /// Rebuilds a puzzle from [toJson] output.
  factory ThreadPuzzle.fromJson(Map<String, Object?> j) {
    final cells = _ints(j['numbers']);
    return ThreadPuzzle(
      size: (j['size'] as num).toInt(),
      numbers: {for (var i = 0; i < cells.length; i++) cells[i]: i + 1},
      solution: _ints(j['solution']),
    );
  }

  /// Grid side n (the grid is n×n).
  final int size;

  /// Cell → number (1..[maxNumber]); 1 is the start cell, [maxNumber] the end cell.
  /// Iterates in number order.
  final Map<int, int> numbers;

  /// The unique path, `cellCount` cells long, from the cell with 1 to the cell with K.
  final List<int> solution;

  /// K, the highest number (it sits on the last cell of the path).
  final int maxNumber;

  /// Number of cells, n*n.
  int get cellCount => size * size;

  /// The cell carrying [number], or null when no cell has it.
  int? cellOf(int number) {
    for (final e in numbers.entries) {
      if (e.value == number) return e.key;
    }
    return null;
  }

  /// Plain JSON: `numbers` is the list of numbered cells in number order (JSON object
  /// keys must be strings, and the order already encodes the numbers).
  Map<String, Object?> toJson() => {
    'size': size,
    'numbers': [for (final e in numbers.entries) e.key],
    'solution': List<int>.of(solution),
  };

  static Map<int, int> _inNumberOrder(Map<int, int> numbers) {
    // Number order (not insertion order) so iteration and JSON never depend on how the
    // map was built.
    final entries = numbers.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return {for (final e in entries) e.key: e.value};
  }

  static List<int> _ints(Object? list) => [
    for (final v in list as List) (v as num).toInt(),
  ];
}
