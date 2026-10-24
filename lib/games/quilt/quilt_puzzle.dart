// Quilt puzzle model: an n×n grid split into rectangles ("patches"), each holding exactly
// one clue that shows its area and/or shape.
//
// Why plain data + JSON: the generator runs inside `Isolate.run`, and the app saves and
// restores games, so everything here crosses isolates and survives a JSON round trip.
// Pure Dart (no Flutter imports).

/// A rectangle's proportions as a clue can show them.
enum QuiltShape {
  /// Width equals height.
  square,

  /// Taller than wide.
  tall,

  /// Wider than tall.
  wide;

  /// The shape of a [width]×[height] rectangle.
  static QuiltShape of(int width, int height) => width == height
      ? QuiltShape.square
      : (height > width ? QuiltShape.tall : QuiltShape.wide);
}

/// An axis-aligned rectangle of cells: top-left [row]/[col] plus size, all in cells.
class QuiltRect {
  /// Creates a rectangle.
  const QuiltRect({
    required this.row,
    required this.col,
    required this.width,
    required this.height,
  });

  /// The rectangle spanned by two corner cells (any order) — handy for drag gestures.
  factory QuiltRect.spanning(int cellA, int cellB, int cols) {
    final ra = cellA ~/ cols, ca = cellA % cols;
    final rb = cellB ~/ cols, cb = cellB % cols;
    final top = ra < rb ? ra : rb, left = ca < cb ? ca : cb;
    return QuiltRect(
      row: top,
      col: left,
      width: (ca - cb).abs() + 1,
      height: (ra - rb).abs() + 1,
    );
  }

  /// Rebuilds a rectangle from [toJson] output.
  factory QuiltRect.fromJson(Map<String, Object?> j) => QuiltRect(
    row: (j['row'] as num).toInt(),
    col: (j['col'] as num).toInt(),
    width: (j['width'] as num).toInt(),
    height: (j['height'] as num).toInt(),
  );

  /// Top row and left column.
  final int row, col;

  /// Size in cells.
  final int width, height;

  /// Number of cells.
  int get area => width * height;

  /// Square, tall or wide.
  QuiltShape get shape => QuiltShape.of(width, height);

  /// Whether [cell] (row-major in a grid [cols] wide) lies inside.
  bool contains(int cell, int cols) {
    final r = cell ~/ cols, c = cell % cols;
    return r >= row && r < row + height && c >= col && c < col + width;
  }

  /// The covered cells, row-major, in a grid [cols] wide.
  Iterable<int> cells(int cols) sync* {
    for (var r = row; r < row + height; r++) {
      for (var c = col; c < col + width; c++) {
        yield r * cols + c;
      }
    }
  }

  /// Whether the rectangle is non-empty and lies inside a [size]×[size] grid.
  bool isInside(int size) =>
      width >= 1 &&
      height >= 1 &&
      row >= 0 &&
      col >= 0 &&
      row + height <= size &&
      col + width <= size;

  /// Whether the two rectangles share at least one cell.
  bool overlaps(QuiltRect o) =>
      row < o.row + o.height &&
      o.row < row + height &&
      col < o.col + o.width &&
      o.col < col + width;

  /// Plain JSON.
  Map<String, Object?> toJson() => {
    'row': row,
    'col': col,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is QuiltRect &&
      other.row == row &&
      other.col == col &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(row, col, width, height);

  @override
  String toString() => 'QuiltRect($row, $col, ${width}x$height)';
}

/// A clue: its [cell], and the [area] and/or [shape] of the patch that holds it.
class QuiltClue {
  /// Creates a clue; at least one of [area] and [shape] must be given.
  const QuiltClue({required this.cell, this.area, this.shape})
    : assert(area != null || shape != null, 'a clue needs an area or a shape');

  /// Rebuilds a clue from [toJson] output.
  factory QuiltClue.fromJson(Map<String, Object?> j) => QuiltClue(
    cell: (j['cell'] as num).toInt(),
    area: (j['area'] as num?)?.toInt(),
    shape: j['shape'] == null
        ? null
        : QuiltShape.values.byName(j['shape']! as String),
  );

  /// Row-major cell index of the clue.
  final int cell;

  /// Patch area, or null for a shape-only clue.
  final int? area;

  /// Patch shape, or null when the clue shows only the area.
  final QuiltShape? shape;

  /// Whether [r] has the area and shape this clue asks for (it does not check that
  /// [r] contains the clue).
  bool matches(QuiltRect r) =>
      (area == null || r.area == area) && (shape == null || r.shape == shape);

  /// Plain JSON; missing parts are left out.
  Map<String, Object?> toJson() => {
    'cell': cell,
    if (area != null) 'area': area,
    if (shape != null) 'shape': shape!.name,
  };

  @override
  bool operator ==(Object other) =>
      other is QuiltClue &&
      other.cell == cell &&
      other.area == area &&
      other.shape == shape;

  @override
  int get hashCode => Object.hash(cell, area, shape);

  @override
  String toString() => 'QuiltClue($cell, area: $area, shape: ${shape?.name})';
}

/// A generated Quilt puzzle; `solution[i]` is the patch of `clues[i]`.
class QuiltPuzzle {
  /// Creates a puzzle; clues are expected in row-major order of their cells.
  QuiltPuzzle({
    required this.size,
    required List<QuiltClue> clues,
    required List<QuiltRect> solution,
  }) : clues = List.unmodifiable(clues),
       solution = List.unmodifiable(solution);

  /// Rebuilds a puzzle from [toJson] output.
  factory QuiltPuzzle.fromJson(Map<String, Object?> j) => QuiltPuzzle(
    size: (j['size'] as num).toInt(),
    clues: [
      for (final c in j['clues'] as List)
        QuiltClue.fromJson((c as Map).cast<String, Object?>()),
    ],
    solution: [
      for (final r in j['solution'] as List)
        QuiltRect.fromJson((r as Map).cast<String, Object?>()),
    ],
  );

  /// Grid side n (the grid is n×n).
  final int size;

  /// One clue per patch.
  final List<QuiltClue> clues;

  /// The unique solution: `solution[i]` holds `clues[i]`.
  final List<QuiltRect> solution;

  /// Index of the clue on [cell], or null.
  int? clueIndexAt(int cell) {
    for (var i = 0; i < clues.length; i++) {
      if (clues[i].cell == cell) return i;
    }
    return null;
  }

  /// Plain JSON.
  Map<String, Object?> toJson() => {
    'size': size,
    'clues': [for (final c in clues) c.toJson()],
    'solution': [for (final r in solution) r.toJson()],
  };
}
