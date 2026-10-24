// Bridges generator tests: validity, uniqueness (by the engine's solver and by an
// independent one), determinism, JSON and speed for every size the app uses.

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';

import 'bridges_fixtures.dart';
import 'bridges_reference.dart';

/// (side, islands) pairs the app uses.
const _sizes = [(5, 6), (6, 9), (7, 12), (8, 16), (9, 20)];
const _doubles = [0.0, 0.3, 0.5];
const _seeds = 25;

BridgesParams _params(int rows, int cols, int islands, double doubles) =>
    BridgesParams(rows: rows, cols: cols, islands: islands, doubles: doubles);

/// Everything a generated puzzle must satisfy except uniqueness.
void _expectValid(
  BridgesPuzzle p,
  BridgesParams params,
  String why, {
  bool exactCount = true,
}) {
  expect(p.rows, params.rows, reason: why);
  expect(p.cols, params.cols, reason: why);
  if (exactCount) {
    expect(p.islands.length, params.islands, reason: '$why: island count');
  } else {
    expect(p.islands.length, lessThanOrEqualTo(params.islands), reason: why);
  }
  final n = p.islands.length;
  // Islands: inside the grid, row-major order, never side by side, needs 1..8.
  for (var i = 0; i < n; i++) {
    final a = p.islands[i];
    expect(a.row, inInclusiveRange(0, p.rows - 1), reason: why);
    expect(a.col, inInclusiveRange(0, p.cols - 1), reason: why);
    expect(a.need, inInclusiveRange(1, 8), reason: '$why: need of $a');
    expect(p.islandAt(a.row, a.col), i, reason: why);
    if (i > 0) {
      final b = p.islands[i - 1];
      expect(
        a.row > b.row || (a.row == b.row && a.col > b.col),
        isTrue,
        reason: '$why: islands not in row-major order',
      );
    }
    for (final (dr, dc) in [(0, 1), (1, 0)]) {
      expect(
        p.islandAt(a.row + dr, a.col + dc),
        isNull,
        reason: '$why: $a touches another island',
      );
    }
  }
  // Links: sorted, visible pairs, one or two bridges, a < b.
  final visible = BridgesRules.pairs(p).toSet();
  for (var i = 0; i < p.solution.length; i++) {
    final l = p.solution[i];
    expect(l.a, lessThan(l.b), reason: why);
    expect(l.count, inInclusiveRange(1, 2), reason: why);
    expect(
      visible.contains((l.a, l.b)),
      isTrue,
      reason: '$why: $l not visible',
    );
    if (i > 0) {
      final k = p.solution[i - 1];
      expect(
        l.a > k.a || (l.a == k.a && l.b > k.b),
        isTrue,
        reason: '$why: unsorted',
      );
    }
  }
  // Needs are exactly the bridges at each island; connected; no crossings.
  final degrees = BridgesRules.degrees(p, p.solution);
  for (var i = 0; i < n; i++) {
    expect(degrees[i], p.islands[i].need, reason: '$why: island $i');
  }
  expect(BridgesRules.connected(p, p.solution), isTrue, reason: why);
  expect(BridgesRules.isSolved(p, p.solution), isTrue, reason: why);
  // The share of double links follows the params.
  final doubles = p.solution.where((l) => l.count == 2).length;
  expect(
    doubles,
    (params.doubles * p.solution.length).round(),
    reason: '$why: doubles',
  );
}

void main() {
  test(
    'every size × doubles × seed gives a valid, unique, connected puzzle',
    () {
      for (final (n, islands) in _sizes) {
        for (final d in _doubles) {
          for (var seed = 0; seed < _seeds; seed++) {
            final params = _params(n, n, islands, d);
            final why = '${n}x$n/$islands doubles $d seed $seed';
            final p = BridgesGenerator.generate(params, seed);
            _expectValid(p, params, why);
            final s = BridgesSolver.search(p);
            expect(s.unique, isTrue, reason: '$why: solver says ${s.count}');
            expect(
              s.first,
              p.solution,
              reason: '$why: solver found another answer',
            );
            expect(BridgesSolver.countSolutions(p), 1, reason: why);
            expect(
              BridgesSolver.findOther(p).unique,
              isTrue,
              reason: '$why: another answer exists',
            );
            // An independent search agrees (no propagation, no shared code).
            expect(
              referenceCount(p),
              1,
              reason: '$why: reference solver disagrees',
            );
          }
        }
      }
    },
  );

  test('other shapes: rectangles, thin grids and denser boards', () {
    final cases = [
      (5, 9, 11),
      (9, 5, 11),
      (3, 8, 5),
      (8, 3, 5),
      (1, 9, 3),
      (4, 4, 5),
      (5, 5, 9),
      (7, 7, 18),
    ];
    for (final (rows, cols, islands) in cases) {
      for (var seed = 0; seed < 10; seed++) {
        final params = _params(rows, cols, islands, 0.3);
        final p = BridgesGenerator.generate(params, seed);
        final why = '${rows}x$cols/$islands seed $seed';
        // Dense requests may come back with fewer islands than asked for.
        _expectValid(p, params, why, exactCount: false);
        expect(BridgesSolver.countSolutions(p), 1, reason: why);
        expect(referenceCount(p), 1, reason: why);
      }
    }
  });

  test('asking for more islands than fit gives a smaller unique puzzle', () {
    final p = BridgesGenerator.generate(_params(5, 5, 40, 0.3), 3);
    expect(p.islands.length, lessThan(40));
    expect(p.islands.length, greaterThanOrEqualTo(2));
    expect(BridgesSolver.countSolutions(p), 1);
    expect(BridgesRules.isSolved(p, p.solution), isTrue);
  });

  test('same seed gives identical JSON; different seeds differ', () {
    for (final (n, islands) in _sizes) {
      for (final d in _doubles) {
        final params = _params(n, n, islands, d);
        final a = jsonEncode(BridgesGenerator.generate(params, 42).toJson());
        final b = jsonEncode(BridgesGenerator.generate(params, 42).toJson());
        final c = jsonEncode(BridgesGenerator.generate(params, 43).toJson());
        expect(a, b, reason: '${n}x$n doubles $d');
        expect(a, isNot(c), reason: '${n}x$n doubles $d');
      }
    }
    // Many seeds really give many puzzles.
    final seen = {
      for (var s = 0; s < 40; s++)
        jsonEncode(
          BridgesGenerator.generate(_params(6, 6, 9, 0.3), s).toJson(),
        ),
    };
    expect(seen.length, greaterThan(35));
  });

  test('the generator does not depend on earlier calls', () {
    final params = _params(8, 8, 16, 0.3);
    final first = jsonEncode(BridgesGenerator.generate(params, 5).toJson());
    for (var s = 0; s < 5; s++) {
      BridgesGenerator.generate(_params(5, 5, 6, 0.5), s);
    }
    expect(jsonEncode(BridgesGenerator.generate(params, 5).toJson()), first);
  });

  test('puzzles are spread over the grid and vary in shape', () {
    var withDoubles = 0, withLoops = 0, bigNeed = 0;
    for (var seed = 0; seed < 40; seed++) {
      final p = BridgesGenerator.generate(_params(9, 9, 20, 0.3), seed);
      var top = 9, bottom = -1, left = 9, right = -1;
      for (final i in p.islands) {
        if (i.row < top) top = i.row;
        if (i.row > bottom) bottom = i.row;
        if (i.col < left) left = i.col;
        if (i.col > right) right = i.col;
      }
      expect(bottom - top, greaterThanOrEqualTo(7), reason: 'seed $seed rows');
      expect(right - left, greaterThanOrEqualTo(7), reason: 'seed $seed cols');
      if (p.solution.any((l) => l.count == 2)) withDoubles++;
      if (p.solution.length >= p.islands.length) withLoops++;
      if (p.islands.any((i) => i.need >= 5)) bigNeed++;
    }
    expect(withDoubles, 40);
    expect(
      withLoops,
      greaterThan(5),
      reason: 'some puzzles should contain loops',
    );
    expect(bigNeed, greaterThan(0));
  });

  test(
    'generates inside an isolate and the puzzle survives the trip',
    () async {
      // The app generates in Isolate.run: the closure may only capture sendable data and
      // the returned puzzle (graph arrays included) must copy across intact.
      const params = BridgesParams(rows: 9, cols: 9, islands: 20, doubles: 0.3);
      final direct = BridgesGenerator.generate(params, 9);
      final sent = await Isolate.run(
        () => BridgesGenerator.generate(params, 9),
      );
      expect(jsonEncode(sent.toJson()), jsonEncode(direct.toJson()));
      expect(BridgesRules.pairs(sent), BridgesRules.pairs(direct));
      expect(BridgesRules.isSolved(sent, sent.solution), isTrue);
      expect(BridgesSolver.countSolutions(sent), 1);
    },
  );

  test('JSON round trip keeps everything', () {
    for (final (n, islands) in _sizes) {
      final p = BridgesGenerator.generate(_params(n, n, islands, 0.3), 7);
      final text = jsonEncode(p.toJson());
      final q = BridgesPuzzle.fromJson(
        jsonDecode(text) as Map<String, Object?>,
      );
      expect(jsonEncode(q.toJson()), text);
      expect(q.rows, p.rows);
      expect(q.cols, p.cols);
      expect(q.islands, p.islands);
      expect(q.solution, p.solution);
      expect(BridgesRules.isSolved(q, q.solution), isTrue);
      expect(BridgesRules.pairs(q), BridgesRules.pairs(p));
    }
    const i = BridgesIsland(row: 2, col: 3, need: 4);
    expect(BridgesIsland.fromJson(i.toJson()), i);
    expect(i.toJson(), {'row': 2, 'col': 3, 'need': 4});
    const l = BridgesLink(1, 5, 2);
    expect(BridgesLink.fromJson(l.toJson()), l);
    expect(l.toJson(), {'a': 1, 'b': 5, 'count': 2});
    // Hand-made puzzles too.
    for (final h in [
      smallPuzzle(),
      ringPuzzle(),
      plusPuzzle(),
      doublePairPuzzle(),
    ]) {
      final back = BridgesPuzzle.fromJson(
        jsonDecode(jsonEncode(h.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), h.toJson());
    }
  });

  test('value equality of islands and links', () {
    const a = BridgesIsland(row: 1, col: 2, need: 3);
    final b = BridgesIsland(row: 1, col: a.col, need: 3);
    expect(identical(a, b), isFalse);
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode);
    expect(a == const BridgesIsland(row: 1, col: 2, need: 4), isFalse);
    expect({a, b}.length, 1);
    const x = BridgesLink(0, 1, 1);
    final y = BridgesLink(0, 1, x.count);
    expect(x == y, isTrue);
    expect(x.hashCode, y.hashCode);
    expect(x == const BridgesLink(0, 1, 2), isFalse);
    expect(x == const BridgesLink(0, 2, 1), isFalse);
    expect({x, y}.length, 1);
    expect(x.withCount(2), const BridgesLink(0, 1, 2));
  });

  test('the puzzle constructor sorts islands and remaps the links', () {
    // The ring of four, islands given in a scrambled order and links reversed.
    final p = BridgesPuzzle(
      rows: 4,
      cols: 4,
      islands: const [
        BridgesIsland(row: 3, col: 3, need: 2),
        BridgesIsland(row: 0, col: 0, need: 2),
        BridgesIsland(row: 3, col: 0, need: 2),
        BridgesIsland(row: 0, col: 3, need: 2),
      ],
      solution: const [
        BridgesLink(0, 2, 1), // (3,3)-(3,0)
        BridgesLink(0, 3, 1), // (3,3)-(0,3)
        BridgesLink(1, 2, 1), // (0,0)-(3,0)
        BridgesLink(1, 3, 1), // (0,0)-(0,3)
      ],
    );
    final ring = ringPuzzle();
    expect(p.toJson(), ring.toJson());
    expect(BridgesRules.isSolved(p, p.solution), isTrue);
    expect(
      () => BridgesPuzzle(
        rows: 2,
        cols: 2,
        islands: const [BridgesIsland(row: 0, col: 5, need: 1)],
        solution: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => BridgesPuzzle(
        rows: 3,
        cols: 3,
        islands: const [
          BridgesIsland(row: 1, col: 1, need: 1),
          BridgesIsland(row: 1, col: 1, need: 2),
        ],
        solution: const [],
      ),
      throwsArgumentError,
    );
  });

  test('bad params are rejected', () {
    expect(
      () => BridgesGenerator.generate(_params(2, 2, 3, 0.3), 0),
      throwsArgumentError,
    );
    expect(
      () => BridgesGenerator.generate(_params(0, 5, 3, 0.3), 0),
      throwsArgumentError,
    );
    expect(
      () => BridgesGenerator.generate(_params(5, 5, 1, 0.3), 0),
      throwsArgumentError,
    );
    expect(
      () => BridgesGenerator.generate(_params(40, 5, 4, 0.3), 0),
      throwsArgumentError,
    );
  });

  test('generation is fast for every size', () {
    final timings = <String, String>{};
    for (final (n, islands) in _sizes) {
      for (final d in [0.0, 0.5]) {
        final params = _params(n, n, islands, d);
        BridgesGenerator.generate(params, 1000); // JIT warm-up
        final sw = Stopwatch();
        var worst = 0;
        const runs = 20;
        for (var seed = 0; seed < runs; seed++) {
          final t0 = sw.elapsedMicroseconds;
          sw.start();
          BridgesGenerator.generate(params, seed);
          sw.stop();
          final us = sw.elapsedMicroseconds - t0;
          if (us > worst) worst = us;
        }
        final avgMs = sw.elapsedMicroseconds / runs / 1000;
        timings['${n}x$n/$islands d$d'] =
            'avg ${avgMs.toStringAsFixed(2)} ms, '
            'max ${(worst / 1000).toStringAsFixed(1)} ms';
        if (n >= 8) expect(avgMs, lessThan(150), reason: 'size $n');
      }
    }
    // ignore: avoid_print
    print('Bridges generation: $timings');
  });
}
