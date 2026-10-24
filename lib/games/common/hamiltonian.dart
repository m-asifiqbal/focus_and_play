// Random Hamiltonian paths on a rectangular grid ("backbite" random walk).
//
// Why: Thread puzzles are one path through every cell, and Twist boards are one
// path cut into word-length pieces. Starting from a snake path and applying many
// random backbite moves gives a well-mixed path that is fully determined by the seed.

import 'dart:math';

import 'grid.dart';

/// Returns a random Hamiltonian path (every cell exactly once, consecutive cells
/// share an edge) for a rows×cols grid. Same seed → same path on every device.
List<int> randomHamiltonianPath(int rows, int cols, Random rng, {int? moves}) {
  final n = rows * cols;
  // Boustrophedon start: left→right, then right→left, …
  final path = <int>[
    for (var r = 0; r < rows; r++)
      for (var k = 0; k < cols; k++) r * cols + (r.isEven ? k : cols - 1 - k),
  ];
  if (n <= 2) return path;
  final pos = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    pos[path[i]] = i;
  }

  void reverseRange(int from, int to) {
    // Reverses path[from..to] inclusive and keeps `pos` in sync.
    while (from < to) {
      final a = path[from], b = path[to];
      path[from] = b;
      path[to] = a;
      pos[b] = from;
      pos[a] = to;
      from++;
      to--;
    }
  }

  final total = moves ?? n * 40;
  for (var step = 0; step < total; step++) {
    final atTail = rng.nextBool();
    final end = atTail ? path[n - 1] : path[0];
    final nbs = neighboursOf(end, rows, cols);
    final next = nbs[rng.nextInt(nbs.length)];
    final i = pos[next];
    if (atTail) {
      if (i == n - 2) continue; // already linked
      // Link tail→next, cut next→path[i+1]: reverse the part after `next`.
      reverseRange(i + 1, n - 1);
    } else {
      if (i == 1) continue;
      // Link head→next, cut path[i-1]→next: reverse the part before `next`.
      reverseRange(0, i - 1);
    }
  }
  return path;
}

/// True when [path] visits every cell of the grid once with edge-adjacent steps.
bool isHamiltonianPath(List<int> path, int rows, int cols) {
  final n = rows * cols;
  if (path.length != n) return false;
  final seen = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    final c = path[i];
    if (c < 0 || c >= n || seen[c]) return false;
    seen[c] = true;
    if (i > 0 && !isOrthogonalNeighbour(path[i - 1], c, cols)) return false;
  }
  return true;
}
