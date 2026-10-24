// Quilt generator: a random split of the grid into rectangles, one clue per patch, then
// targeted clue moves until the solver proves the answer is unique.
//
// Why this shape: a random partition with random clue cells is often ambiguous (two
// patches can swap cells). When the solver finds another solution we move a clue to a
// cell of its patch that the other solution's patch lacks, which rules that solution
// out while keeping the intended one valid. If a partition keeps resisting we take a
// fresh one from the same `Random`, and after a few of those we also reveal shapes
// (or areas) that tell the two solutions apart. All limits are counts, so a seed gives
// the same puzzle on every device.

import 'dart:math';

import 'package:focus_and_play_mindgame/games/quilt/quilt_puzzle.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt_solver.dart';

/// Generation settings for a Quilt puzzle.
class QuiltParams {
  /// Creates params; [size] is 5..8 in the app (2..8 accepted).
  const QuiltParams({
    required this.size,
    this.maxArea = 8,
    this.shapeClues = 0,
    this.shapeOnly = 0,
  });

  /// Grid side n (the grid is n×n).
  final int size;

  /// Largest patch area the generator may cut (patches are always at least 2 cells).
  final int maxArea;

  /// Share (0..1) of clues that also show their patch's shape.
  final double shapeClues;

  /// Share (0..1) of those shape clues that hide the area (harder).
  final double shapeOnly;
}

/// Builds Quilt puzzles; deterministic for a given params + seed.
class QuiltGenerator {
  QuiltGenerator._();

  static const int _fixesPerPartition = 30;
  static const int _revealAfter =
      3; // partitions tried before revealing extra clues
  static const int _maxPartitions = 400;
  static const int _partitionSteps = 4000;

  /// Generates a puzzle with exactly one solution.
  static QuiltPuzzle generate(QuiltParams p, int seed) {
    final n = p.size;
    if (n < 2 || n > 8) throw ArgumentError.value(n, 'size', 'must be 2..8');
    // Patches have 2..maxArea cells; with dominoes only, an odd grid can't be tiled.
    if (p.maxArea < 2 || (p.maxArea == 2 && n.isOdd)) {
      throw ArgumentError.value(p.maxArea, 'maxArea', 'too small for size $n');
    }
    final rng = Random(seed);
    for (var attempt = 0; attempt < _maxPartitions; attempt++) {
      final rects = _partition(n, p.maxArea, rng);
      final m = rects.length;
      final clueCell = [
        for (final r in rects) _cellAt(r, rng.nextInt(r.area), n),
      ];
      final showShape = List<bool>.filled(m, false);
      final showArea = List<bool>.filled(m, true);
      _assignShapes(p, rng, showShape, showArea);
      final reveal = attempt >= _revealAfter;
      for (var fix = 0; fix < _fixesPerPartition; fix++) {
        final clues = [
          for (var i = 0; i < m; i++)
            QuiltClue(
              cell: clueCell[i],
              area: showArea[i] ? rects[i].area : null,
              shape: showShape[i] ? rects[i].shape : null,
            ),
        ];
        final r = QuiltSolver.findOther(n, clues, rects);
        if (r.unique) return _sorted(n, clues, rects);
        final other = r.alternative;
        if (other == null) break; // too hard to settle: start over
        if (!_fix(
          n,
          rects,
          other,
          clueCell,
          showShape,
          showArea,
          rng,
          reveal,
        )) {
          break;
        }
      }
    }
    throw StateError('Quilt: no unique puzzle for size $n seed $seed');
  }

  /// Random partition into rectangles of area 2..[maxArea], in row-major order of
  /// their top-left cells. Retries (continuing the same random stream) until a fill
  /// succeeds; each try is a bounded backtracking search.
  static List<QuiltRect> _partition(int n, int maxArea, Random rng) {
    for (var i = 0; i < _maxPartitions; i++) {
      final rects = _Partitioner(n, maxArea, rng, _partitionSteps).run();
      if (rects != null) return rects;
    }
    throw StateError('Quilt: could not split a ${n}x$n grid');
  }

  /// Picks exactly round(share × count) clues to show a shape, and of those exactly
  /// round(share × count) to hide the area, so a difficulty level always feels the
  /// same.
  static void _assignShapes(
    QuiltParams p,
    Random rng,
    List<bool> showShape,
    List<bool> showArea,
  ) {
    final m = showShape.length;
    final order = List<int>.generate(m, (i) => i);
    for (var i = m - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    final shapes = (p.shapeClues.clamp(0.0, 1.0) * m).round();
    final hidden = (p.shapeOnly.clamp(0.0, 1.0) * shapes).round();
    for (var k = 0; k < shapes; k++) {
      showShape[order[k]] = true;
      if (k < hidden) showArea[order[k]] = false;
    }
  }

  /// Changes one clue so that [other] stops being a solution; false when impossible.
  ///
  /// Preferred: move a clue to a cell of its intended patch that its patch in [other]
  /// does not contain (keeps the clue's kind, so the difficulty mix is unchanged).
  /// When [reveal] is on, first try showing a hidden shape/area that differs between
  /// the two patches.
  static bool _fix(
    int n,
    List<QuiltRect> rects,
    List<QuiltRect> other,
    List<int> clueCell,
    List<bool> showShape,
    List<bool> showArea,
    Random rng,
    bool reveal,
  ) {
    final differ = [
      for (var i = 0; i < rects.length; i++)
        if (rects[i] != other[i]) i,
    ];
    if (reveal) {
      final options = <int>[]; // encoded as clue * 2 + (0 = shape, 1 = area)
      for (final i in differ) {
        if (!showShape[i] && rects[i].shape != other[i].shape) {
          options.add(i * 2);
        }
        if (!showArea[i] && rects[i].area != other[i].area) {
          options.add(i * 2 + 1);
        }
      }
      if (options.isNotEmpty) {
        final o = options[rng.nextInt(options.length)];
        if (o.isEven) {
          showShape[o ~/ 2] = true;
        } else {
          showArea[o ~/ 2] = true;
        }
        return true;
      }
    }
    final movable = <int>[];
    for (final i in differ) {
      if (rects[i].cells(n).any((c) => !other[i].contains(c, n))) {
        movable.add(i);
      }
    }
    if (movable.isEmpty) return false;
    final i = movable[rng.nextInt(movable.length)];
    final spots = [
      for (final c in rects[i].cells(n))
        if (!other[i].contains(c, n)) c,
    ];
    clueCell[i] = spots[rng.nextInt(spots.length)];
    return true;
  }

  static int _cellAt(QuiltRect r, int k, int n) =>
      (r.row + k ~/ r.width) * n + r.col + k % r.width;

  /// The puzzle with clues (and their patches) in row-major order of the clue cells.
  static QuiltPuzzle _sorted(
    int n,
    List<QuiltClue> clues,
    List<QuiltRect> rects,
  ) {
    final order = List<int>.generate(clues.length, (i) => i)
      ..sort((a, b) => clues[a].cell.compareTo(clues[b].cell));
    return QuiltPuzzle(
      size: n,
      clues: [for (final i in order) clues[i]],
      solution: [for (final i in order) rects[i]],
    );
  }
}

/// One bounded backtracking attempt at a random partition.
class _Partitioner {
  _Partitioner(this.n, this.maxArea, this.rng, this.budget)
    : covered = List<bool>.filled(n * n, false);

  final int n, maxArea;
  final Random rng;
  final List<bool> covered;
  final rects = <QuiltRect>[];
  int budget;

  List<QuiltRect>? run() => _fill(0) ? rects : null;

  /// The first uncovered cell (row-major) is always the top-left of its patch, so we
  /// only ever choose a size for it.
  bool _fill(int from) {
    var c = from;
    while (c < n * n && covered[c]) {
      c++;
    }
    if (c == n * n) return true;
    if (--budget < 0) return false;
    final row = c ~/ n, col = c % n;
    // Cells below a free run in this row are free too (a patch from above covering
    // them would also cover this row), so only the run length limits the width.
    var maxW = 0;
    while (col + maxW < n && !covered[c + maxW]) {
      maxW++;
    }
    final sizes = <int>[], weights = <int>[];
    for (var h = 1; h <= n - row; h++) {
      for (var w = 1; w <= maxW; w++) {
        final a = w * h;
        if (a < 2) continue;
        if (a > maxArea) break;
        sizes.add(h * 16 + w);
        weights.add(_weight(w, h));
      }
    }
    while (sizes.isNotEmpty) {
      var total = 0;
      for (final x in weights) {
        total += x;
      }
      var pick = rng.nextInt(total), k = 0;
      while (pick >= weights[k]) {
        pick -= weights[k++];
      }
      final h = sizes[k] ~/ 16, w = sizes[k] % 16;
      sizes.removeAt(k);
      weights.removeAt(k);
      final rect = QuiltRect(row: row, col: col, width: w, height: h);
      _mark(rect, true);
      rects.add(rect);
      if (!_strands(rect) && _fill(c + w)) return true;
      rects.removeLast();
      _mark(rect, false);
      if (budget < 0) return false;
    }
    return false;
  }

  /// Favours medium patches; long 1-wide strips are halved because they make dull,
  /// ambiguous clues.
  int _weight(int w, int h) {
    final a = w * h;
    final up = a - 1, down = maxArea - a + 2;
    final base = up < down ? up : down;
    final thin = (w == 1 || h == 1) && a >= 4;
    return base * (thin ? 1 : 2);
  }

  void _mark(QuiltRect r, bool value) {
    for (final c in r.cells(n)) {
      covered[c] = value;
    }
  }

  /// True when placing [r] left an uncovered cell next to it with no uncovered
  /// neighbour — it could only ever be a 1×1 patch.
  bool _strands(QuiltRect r) {
    bool isolated(int row, int col) {
      if (row < 0 || col < 0 || row >= n || col >= n) return false;
      final c = row * n + col;
      if (covered[c]) return false;
      return (row == 0 || covered[c - n]) &&
          (row == n - 1 || covered[c + n]) &&
          (col == 0 || covered[c - 1]) &&
          (col == n - 1 || covered[c + 1]);
    }

    for (var x = r.col; x < r.col + r.width; x++) {
      if (isolated(r.row - 1, x) || isolated(r.row + r.height, x)) return true;
    }
    for (var y = r.row; y < r.row + r.height; y++) {
      if (isolated(y, r.col - 1) || isolated(y, r.col + r.width)) return true;
    }
    return false;
  }
}
