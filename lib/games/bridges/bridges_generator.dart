// Bridges generator: grow a random connected island layout whose bridges are the
// intended answer, then keep it only if the solver proves it has no second solution.
//
// Why "grow, prove, retry" and not "repair": the answer is built first (so a solution
// always exists and the needs are simply the bridge counts at each island), and layouts
// at the app's densities (about a quarter of the cells are islands) are unique after a
// handful of tries — the solver's propagation settles each check in one to three nodes.
// A layout that has another solution or that the node limit cannot settle is dropped and
// the next one is drawn from the same `Random`, so a seed gives the same puzzle on every
// device (only list order, `Random(seed)` and counted limits are involved).
//
// If the grid cannot hold the requested islands (or no unique layout turns up within the
// attempt budget) the generator asks for one island fewer, so it always returns a puzzle;
// callers can compare `islands.length` with the request.

import 'dart:math';

import 'package:focus_and_play_mindgame/games/bridges/bridges_puzzle.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges_rules.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges_solver.dart';

/// Builds Bridges puzzles; deterministic for a given params + seed.
class BridgesGenerator {
  BridgesGenerator._();

  /// Layouts tried for the requested island count before asking for one island fewer.
  static const int _attempts = 300;

  /// Layouts tried at each smaller island count.
  static const int _fallbackAttempts = 40;

  /// Attempts during which a layout must also reach (almost) every edge of the grid, so
  /// puzzles are not huddled in a corner; after that any unique layout is accepted.
  static const int _spreadAttempts = 100;

  /// Node budget of the uniqueness proof; real layouts need one to a few nodes.
  static const int _nodeLimit = 4000;

  /// Generates a puzzle with exactly one solution: connected islands (never next to
  /// each other), needs of 1..8, and [BridgesParams.doubles] of the solution's links
  /// drawn as two bridges (rounded to a whole number of links).
  ///
  /// Throws [ArgumentError] for a grid that cannot hold a link (no side of at least 3)
  /// or fewer than 2 islands.
  static BridgesPuzzle generate(BridgesParams p, int seed) {
    if (p.rows < 1 || p.cols < 1 || (p.rows < 3 && p.cols < 3)) {
      throw ArgumentError.value('${p.rows}x${p.cols}', 'grid', 'too small');
    }
    if (p.rows > 30 || p.cols > 30) {
      throw ArgumentError.value('${p.rows}x${p.cols}', 'grid', 'too large');
    }
    if (p.islands < 2) {
      throw ArgumentError.value(p.islands, 'islands', 'need at least 2');
    }
    final rng = Random(seed);
    for (var target = p.islands; target >= 2; target--) {
      final tries = target == p.islands ? _attempts : _fallbackAttempts;
      for (var attempt = 0; attempt < tries; attempt++) {
        final layout = _Layout(p.rows, p.cols);
        if (!layout.grow(target, rng, 0.25 + 0.5 * rng.nextDouble())) continue;
        layout.addExtraLinks(rng, 0.5);
        if (target == p.islands &&
            attempt < _spreadAttempts &&
            !layout.spread()) {
          continue;
        }
        layout.makeDoubles(rng, p.doubles);
        final puzzle = layout.toPuzzle();
        final r = BridgesSolver.findOther(puzzle, nodeLimit: _nodeLimit);
        if (r.unique && BridgesRules.isSolved(puzzle, puzzle.solution)) {
          return puzzle;
        }
      }
    }
    throw StateError('Bridges: no unique puzzle for ${p.rows}x${p.cols}');
  }
}

/// A growing layout: islands, the intended links between them and which cells they
/// occupy (so bridges never cross and islands never touch).
class _Layout {
  _Layout(this.rows, this.cols)
    : _cell = List<int>.filled(rows * cols, _empty),
      _island = List<int>.filled(rows * cols, -1);

  static const int _empty = 0, _isl = 1, _across = 2, _down = 3;

  /// Direction steps: up, right, down, left (so `(d + 2) % 4` is the opposite).
  static const _dr = [-1, 0, 1, 0];
  static const _dc = [0, 1, 0, -1];

  final int rows, cols;
  final List<int> _cell; // what occupies each cell
  final List<int> _island; // island index per island cell
  final _pos = <int>[]; // cell of each island, in creation order
  final _used = <int>[]; // per island: bitmask of directions that hold a link
  final _la = <int>[], _lb = <int>[], _lc = <int>[]; // links: a < b, count

  bool _free(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols && _cell[r * cols + c] == _empty;

  bool _isIsland(int r, int c) =>
      r >= 0 && c >= 0 && r < rows && c < cols && _cell[r * cols + c] == _isl;

  /// Places [target] islands: the first anywhere, each next one at least two cells from
  /// an island along a free line, joined to it by a bridge. [loopChance] is how likely a
  /// new island is also linked to other islands it can see.
  bool grow(int target, Random rng, double loopChance) {
    _addIsland(rng.nextInt(rows * cols));
    while (_pos.length < target) {
      final options =
          <int>[]; // island * 4 + direction with room for a new island
      for (var u = 0; u < _pos.length; u++) {
        for (var d = 0; d < 4; d++) {
          if (_used[u] & (1 << d) == 0 && _distances(u, d).isNotEmpty) {
            options.add(u * 4 + d);
          }
        }
      }
      if (options.isEmpty) return false;
      final pick = options[rng.nextInt(options.length)];
      final u = pick ~/ 4, d = pick % 4;
      final ds = _distances(u, d);
      var total = 0;
      for (final x in ds) {
        total += _weight(x);
      }
      var w = rng.nextInt(total), k = 0;
      while (w >= _weight(ds[k])) {
        w -= _weight(ds[k++]);
      }
      final r = _pos[u] ~/ cols + _dr[d] * ds[k];
      final c = _pos[u] % cols + _dc[d] * ds[k];
      final v = _addIsland(r * cols + c);
      _link(u, v, 1);
      for (var e = 0; e < 4; e++) {
        if (e != (d + 2) % 4) _tryLink(v, e, rng, loopChance);
      }
    }
    return true;
  }

  /// Shorter bridges are likelier, which keeps puzzles dense.
  int _weight(int distance) => switch (distance) {
    2 => 4,
    3 => 3,
    4 => 2,
    _ => 1,
  };

  /// Distances at which a new island fits along direction [d] from island [u]: the cells
  /// up to it are free (a bridge can run there) and it touches no island.
  List<int> _distances(int u, int d) {
    final r0 = _pos[u] ~/ cols, c0 = _pos[u] % cols;
    final out = <int>[];
    for (var k = 1; _free(r0 + _dr[d] * k, c0 + _dc[d] * k); k++) {
      if (k < 2) continue;
      final r = r0 + _dr[d] * k, c = c0 + _dc[d] * k;
      var ok = true;
      for (var e = 0; e < 4; e++) {
        if (e != (d + 2) % 4 && _isIsland(r + _dr[e], c + _dc[e])) ok = false;
      }
      if (ok) out.add(k);
    }
    return out;
  }

  int _addIsland(int cell) {
    _cell[cell] = _isl;
    _island[cell] = _pos.length;
    _pos.add(cell);
    _used.add(0);
    return _pos.length - 1;
  }

  /// Records a bridge of [count] between islands [a] and [b] (in line) and marks the
  /// cells between them.
  void _link(int a, int b, int count) {
    final ra = _pos[a] ~/ cols, ca = _pos[a] % cols;
    final rb = _pos[b] ~/ cols, cb = _pos[b] % cols;
    final horizontal = ra == rb;
    final d = horizontal ? (cb > ca ? 1 : 3) : (rb > ra ? 2 : 0);
    var r = ra + _dr[d], c = ca + _dc[d];
    while (r != rb || c != cb) {
      _cell[r * cols + c] = horizontal ? _across : _down;
      r += _dr[d];
      c += _dc[d];
    }
    _used[a] |= 1 << d;
    _used[b] |= 1 << ((d + 2) % 4);
    _la.add(a < b ? a : b);
    _lb.add(a < b ? b : a);
    _lc.add(count);
  }

  /// With probability [chance], links island [a] to the first island in direction [d]
  /// when the way is clear and neither island already has a bridge on that side.
  void _tryLink(int a, int d, Random rng, double chance) {
    if (_used[a] & (1 << d) != 0) return;
    final r0 = _pos[a] ~/ cols, c0 = _pos[a] % cols;
    var k = 1;
    while (_free(r0 + _dr[d] * k, c0 + _dc[d] * k)) {
      k++;
    }
    final r = r0 + _dr[d] * k, c = c0 + _dc[d] * k;
    if (k < 2 || !_isIsland(r, c)) return;
    final b = _island[r * cols + c];
    if (_used[b] & (1 << ((d + 2) % 4)) != 0) return;
    if (rng.nextDouble() < chance) _link(a, b, 1);
  }

  /// A last pass over every island's right and lower neighbour: more loops make the
  /// puzzle richer (and its uniqueness less certain, which the solver then judges).
  void addExtraLinks(Random rng, double chance) {
    for (var a = 0; a < _pos.length; a++) {
      _tryLink(a, 1, rng, chance);
      _tryLink(a, 2, rng, chance);
    }
  }

  /// Whether the islands reach within one cell of every side of the grid.
  bool spread() {
    var r0 = rows, r1 = -1, c0 = cols, c1 = -1;
    for (final cell in _pos) {
      final r = cell ~/ cols, c = cell % cols;
      if (r < r0) r0 = r;
      if (r > r1) r1 = r;
      if (c < c0) c0 = c;
      if (c > c1) c1 = c;
    }
    return r1 - r0 + 1 >= rows - 1 && c1 - c0 + 1 >= cols - 1;
  }

  /// Turns exactly round(share × links) randomly chosen links into double bridges.
  void makeDoubles(Random rng, double share) {
    final m = _la.length;
    final order = List<int>.generate(m, (i) => i);
    for (var i = m - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    final k = (share.clamp(0.0, 1.0) * m).round();
    for (var i = 0; i < k; i++) {
      _lc[order[i]] = 2;
    }
  }

  /// The layout as a puzzle: each island needs the bridges attached to it.
  BridgesPuzzle toPuzzle() {
    final need = List<int>.filled(_pos.length, 0);
    for (var i = 0; i < _la.length; i++) {
      need[_la[i]] += _lc[i];
      need[_lb[i]] += _lc[i];
    }
    return BridgesPuzzle(
      rows: rows,
      cols: cols,
      islands: [
        for (var i = 0; i < _pos.length; i++)
          BridgesIsland(
            row: _pos[i] ~/ cols,
            col: _pos[i] % cols,
            need: need[i],
          ),
      ],
      solution: [
        for (var i = 0; i < _la.length; i++)
          BridgesLink(_la[i], _lb[i], _lc[i]),
      ],
    );
  }
}
