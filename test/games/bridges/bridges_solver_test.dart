// Bridges solver tests: known counts on hand-made puzzles, agreement with brute force on
// hundreds of random layouts, the node limit, solve and findOther.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';

import 'bridges_fixtures.dart';
import 'bridges_reference.dart';

void main() {
  group('hand-made puzzles', () {
    test('unique puzzles count 1 and find the stored answer', () {
      for (final p in [
        smallPuzzle(),
        ringPuzzle(),
        plusPuzzle(),
        doublePairPuzzle(),
        chordsPuzzle(const [2, 2, 2, 2, 2, 2, 2, 2]),
      ]) {
        expect(BridgesSolver.countSolutions(p), 1, reason: '${p.toJson()}');
        final found = BridgesSolver.solve(p);
        expect(found, isNotNull);
        expect(BridgesRules.isSolved(p, found!), isTrue);
        if (p.solution.isNotEmpty) expect(found, p.solution);
        expect(bruteForce(p), hasLength(1));
        expect(referenceCount(p), 1);
      }
    });

    test('the ring needs the connectivity rule', () {
      final p = ringPuzzle();
      // Three arrangements give every island two bridges; only the ring is one group.
      expect(bruteForce(p, requireConnected: false), hasLength(3));
      expect(BridgesSolver.countSolutions(p), 1);
      // The same on the 8-island board with chords through the middle.
      final q = chordsPuzzle(const [2, 2, 2, 2, 2, 2, 2, 2]);
      expect(bruteForce(q, requireConnected: false), hasLength(3));
      expect(BridgesSolver.countSolutions(q), 1);
    });

    test('crossing bridges are excluded', () {
      // Without the crossing rule the two doubled chords would be an answer.
      final p = chordsPuzzle(const [2, 4, 2, 4, 4, 2, 4, 2]);
      expect(bruteForce(p, forbidCrossing: false), hasLength(1));
      expect(bruteForce(p), isEmpty);
      expect(BridgesSolver.countSolutions(p), 0);
      expect(BridgesSolver.solve(p), isNull);
    });

    test('impossible and ambiguous puzzles', () {
      expect(BridgesSolver.countSolutions(impossiblePuzzle()), 0);
      expect(BridgesSolver.solve(impossiblePuzzle()), isNull);
      final ladder = ladderPuzzle();
      expect(bruteForce(ladder), hasLength(2));
      expect(BridgesSolver.countSolutions(ladder), 2);
      expect(BridgesSolver.countSolutions(ladder, limit: 5), 2);
      expect(BridgesSolver.countSolutions(ladder, limit: 1), 1);
      expect(referenceCount(ladder), 2);
    });
  });

  test('agrees with brute force on random layouts (needs from random bridges)', () {
    final rng = Random(7);
    var checked = 0, solvable = 0, ambiguous = 0;
    for (var t = 0; t < 4000; t++) {
      final n = 4 + rng.nextInt(3);
      final m = 4 + rng.nextInt(6);
      final cells = <int>{};
      while (cells.length < m) {
        cells.add(rng.nextInt(n * n));
      }
      final sorted = cells.toList()..sort();
      final bare = BridgesPuzzle(
        rows: n,
        cols: n,
        islands: [
          for (final c in sorted)
            BridgesIsland(row: c ~/ n, col: c % n, need: 1),
        ],
        solution: const [],
      );
      final g = bare.graph;
      if (g.pairs.length > 11) continue;
      // Random non-crossing bridges decide the needs (so many puzzles are solvable).
      final cnt = List<int>.filled(g.pairs.length, 0);
      for (var q = 0; q < cnt.length; q++) {
        final v = rng.nextInt(3);
        if (v > 0 && !g.crossers[q].any((x) => cnt[x] > 0)) cnt[q] = v;
      }
      final need = List<int>.filled(m, 0);
      for (var q = 0; q < cnt.length; q++) {
        need[g.pairA[q]] += cnt[q];
        need[g.pairB[q]] += cnt[q];
      }
      if (t.isEven) {
        final i = rng.nextInt(m);
        need[i] += rng.nextBool() ? 1 : -1; // sometimes break it on purpose
      }
      final p = BridgesPuzzle(
        rows: n,
        cols: n,
        islands: [
          for (var i = 0; i < m; i++)
            BridgesIsland(
              row: bare.islands[i].row,
              col: bare.islands[i].col,
              need: max(1, need[i]),
            ),
        ],
        solution: const [],
      );
      final expected = bruteForce(p).length;
      checked++;
      if (expected > 0) solvable++;
      if (expected > 1) ambiguous++;
      expect(
        BridgesSolver.countSolutions(p, limit: 100000),
        expected,
        reason: 'islands ${p.islands}',
      );
      expect(
        BridgesSolver.countSolutions(p),
        min(expected, 2),
        reason: 'limit 2, islands ${p.islands}',
      );
      expect(referenceCount(p, limit: 100000), expected);
    }
    // The comparison must actually have covered solvable and ambiguous layouts.
    expect(checked, greaterThan(1500));
    expect(solvable, greaterThan(150));
    expect(ambiguous, greaterThan(10));
  });

  test('node limit: not proven means the limit comes back', () {
    final p = smallPuzzle();
    final full = BridgesSolver.search(p);
    expect(full.count, 1);
    expect(full.limitHit, isFalse);
    expect(full.unique, isTrue);
    expect(full.first, p.solution);
    // No node budget at all: nothing is proven.
    final cut = BridgesSolver.search(p, nodeLimit: 0);
    expect(cut.limitHit, isTrue);
    expect(cut.unique, isFalse);
    expect(BridgesSolver.countSolutions(p, nodeLimit: 0), 2);
    expect(BridgesSolver.countSolutions(p, limit: 3, nodeLimit: 0), 3);
    expect(BridgesSolver.solve(p, nodeLimit: 0), isNull);
    // An ambiguous puzzle needs branching, so a budget of one node is not enough.
    expect(BridgesSolver.search(ladderPuzzle(), nodeLimit: 1).limitHit, isTrue);
    expect(BridgesSolver.search(ladderPuzzle()).nodes, greaterThan(1));
  });

  test(
    'findOther: none on a unique puzzle, a valid different one otherwise',
    () {
      final unique = smallPuzzle();
      final r = BridgesSolver.findOther(unique);
      expect(r.unique, isTrue);
      expect(r.alternative, isNull);
      expect(r.limitHit, isFalse);

      // The ladder with one of its two answers stored: the other one is found.
      final answers = bruteForce(ladderPuzzle());
      for (final stored in answers) {
        final base = ladderPuzzle();
        final p = BridgesPuzzle(
          rows: base.rows,
          cols: base.cols,
          islands: base.islands,
          solution: stored,
        );
        final other = BridgesSolver.findOther(p);
        expect(other.unique, isFalse);
        expect(other.alternative, isNotNull);
        expect(other.alternative, isNot(stored));
        expect(BridgesRules.isSolved(p, other.alternative!), isTrue);
      }
      expect(
        BridgesSolver.findOther(smallPuzzle(), nodeLimit: 0).limitHit,
        isTrue,
      );
    },
  );

  test('search is deterministic and ignores the stored solution', () {
    final base = smallPuzzle();
    final wrongStored = BridgesPuzzle(
      rows: base.rows,
      cols: base.cols,
      islands: base.islands,
      solution: const [],
    );
    final a = BridgesSolver.search(base);
    final b = BridgesSolver.search(wrongStored);
    expect(b.count, a.count);
    expect(b.nodes, a.nodes);
    expect(b.first, a.first);
  });
}
