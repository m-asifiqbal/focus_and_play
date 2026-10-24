// Grid helpers shared by every puzzle engine.
//
// Cells are addressed by a single index `r * cols + c`, row-major, top-left first.
// Pure Dart (no Flutter imports) so engines can run inside an isolate.

/// Row of a cell index.
int rowOf(int cell, int cols) => cell ~/ cols;

/// Column of a cell index.
int colOf(int cell, int cols) => cell % cols;

/// True when two cells share an edge (no diagonals).
bool isOrthogonalNeighbour(int a, int b, int cols) {
  final dr = (a ~/ cols - b ~/ cols).abs();
  final dc = (a % cols - b % cols).abs();
  return dr + dc == 1;
}

/// Edge neighbours of [cell] in a rows×cols grid, in a fixed order (up, right, down, left).
List<int> neighboursOf(int cell, int rows, int cols) {
  final r = cell ~/ cols, c = cell % cols;
  return [
    if (r > 0) cell - cols,
    if (c < cols - 1) cell + 1,
    if (r < rows - 1) cell + cols,
    if (c > 0) cell - 1,
  ];
}
