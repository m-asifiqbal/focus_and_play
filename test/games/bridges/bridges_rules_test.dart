// Bridges rules tests: visible pairs, crossings, the tap cycle, degrees, connectivity,
// the solved check, wrong bridges and hints (on hand-made and generated puzzles).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';

import 'bridges_fixtures.dart';
import 'bridges_reference.dart';

/// Sets the total of link `a`–`b` to [count] (0 removes it), as the UI does with a hint.
List<BridgesLink> setLink(List<BridgesLink> links, int a, int b, int count) {
  final out = [
    for (final l in links)
      if (!(l.a == a && l.b == b)) l,
    if (count > 0) BridgesLink(a, b, count),
  ]..sort((x, y) => x.a != y.a ? x.a.compareTo(y.a) : x.b.compareTo(y.b));
  return out;
}

/// A generated puzzle together with a visible pair its answer does not use (the first
/// seed from 11 up that has one).
(BridgesPuzzle, (int, int)) puzzleWithUnusedPair() {
  for (var seed = 11; seed < 300; seed++) {
    final p = BridgesGenerator.generate(
      const BridgesParams(rows: 7, cols: 7, islands: 12, doubles: .3),
      seed,
    );
    final used = {for (final l in p.solution) (l.a, l.b)};
    for (final x in BridgesRules.pairs(p)) {
      if (!used.contains(x)) return (p, x);
    }
  }
  throw StateError('no puzzle with an unused pair');
}

void main() {
  final small = smallPuzzle();

  group('geometry', () {
    test('pairs: visible neighbours only, ordered by (a, b)', () {
      expect(BridgesRules.pairs(small), [
        (0, 1),
        (0, 2),
        (1, 3),
        (2, 3),
        (2, 4),
        (4, 5),
      ]);
      // Three in a row: the outer two do not see each other through the middle one.
      final row = makePuzzle(1, 7, [(0, 0, 1), (0, 3, 2), (0, 6, 1)]);
      expect(BridgesRules.pairs(row), [(0, 1), (1, 2)]);
      // Islands in different rows and columns never pair up.
      final diagonal = makePuzzle(5, 5, [(0, 0, 1), (2, 2, 1), (4, 4, 1)]);
      expect(BridgesRules.pairs(diagonal), isEmpty);
      // A column blocked by an island in between.
      final column = makePuzzle(5, 3, [(0, 1, 1), (2, 1, 2), (4, 1, 1)]);
      expect(BridgesRules.pairs(column), [(0, 1), (1, 2)]);
      expect(BridgesRules.pairs(plusPuzzle()), [
        (0, 2),
        (1, 2),
        (2, 3),
        (2, 4),
      ]);
    });

    test('islandAt and cellOf', () {
      expect(small.islandAt(0, 1), 0);
      expect(small.islandAt(4, 4), 5);
      expect(small.islandAt(1, 1), isNull);
      expect(small.islandAt(-1, 0), isNull);
      expect(small.islandAt(0, 5), isNull);
      expect(small.islandAt(5, 0), isNull);
      expect(small.cellOf(5), 4 * 5 + 4);
    });

    test('cross: strictly inside both, shared islands and parallels do not', () {
      // N(0,2) W(2,0) E(2,4) S(4,2): N–S and W–E meet at the middle.
      final plus = makePuzzle(5, 5, [
        (0, 2, 1),
        (2, 0, 1),
        (2, 4, 1),
        (4, 2, 1),
      ]);
      expect(BridgesRules.cross(plus, 0, 3, 1, 2), isTrue);
      expect(BridgesRules.cross(plus, 1, 2, 0, 3), isTrue); // either order
      expect(BridgesRules.cross(plus, 3, 0, 2, 1), isTrue); // either direction
      // Sharing an island is not crossing (an L: 0–1 along the row, 0–2 down).
      expect(BridgesRules.cross(small, 0, 1, 0, 2), isFalse);
      expect(BridgesRules.cross(small, 2, 3, 1, 3), isFalse);
      // Parallel and identical segments.
      expect(BridgesRules.cross(small, 0, 1, 2, 3), isFalse);
      expect(BridgesRules.cross(small, 0, 2, 1, 3), isFalse);
      expect(BridgesRules.cross(small, 0, 1, 0, 1), isFalse);
      // A segment that stops short of the other's line does not cross it.
      final t = makePuzzle(5, 5, [(0, 0, 1), (0, 2, 1), (2, 3, 1), (2, 1, 1)]);
      // 0:(0,0) 1:(0,2) 2:(2,1) 3:(2,3): the row 0 segment is above the row 2 one.
      expect(BridgesRules.cross(t, 0, 1, 2, 3), isFalse);
      // Out-of-range indices are harmless.
      expect(BridgesRules.cross(small, 0, 9, 1, 2), isFalse);
    });

    test('cross agrees with the pair graph on generated puzzles', () {
      final p = BridgesGenerator.generate(
        const BridgesParams(rows: 8, cols: 8, islands: 16, doubles: .3),
        3,
      );
      final pairs = BridgesRules.pairs(p);
      var crossings = 0;
      for (var x = 0; x < pairs.length; x++) {
        for (var y = 0; y < pairs.length; y++) {
          final c = BridgesRules.cross(
            p,
            pairs[x].$1,
            pairs[x].$2,
            pairs[y].$1,
            pairs[y].$2,
          );
          expect(p.graph.crossers[x].contains(y), c);
          if (c) crossings++;
        }
      }
      expect(
        crossings,
        greaterThan(0),
        reason: 'the test needs some crossings',
      );
    });
  });

  group('drawing', () {
    final plus = makePuzzle(5, 5, [(0, 2, 1), (2, 0, 1), (2, 4, 1), (4, 2, 1)]);

    test('canAdd: visible pair and nothing crossing it', () {
      expect(BridgesRules.canAdd(small, const [], 0, 1), isTrue);
      expect(BridgesRules.canAdd(small, const [], 1, 0), isTrue);
      expect(
        BridgesRules.canAdd(small, const [], 0, 5),
        isFalse,
      ); // not in line
      expect(BridgesRules.canAdd(small, const [], 3, 4), isFalse);
      expect(BridgesRules.canAdd(small, const [], 2, 2), isFalse);
      expect(BridgesRules.canAdd(small, const [], 0, 7), isFalse);
      // A link on the same pair, or sharing an island, does not block.
      expect(
        BridgesRules.canAdd(small, [const BridgesLink(0, 1, 1)], 0, 1),
        isTrue,
      );
      expect(
        BridgesRules.canAdd(small, [const BridgesLink(0, 1, 2)], 0, 2),
        isTrue,
      );
      // The vertical bridge blocks the horizontal one.
      final down = [const BridgesLink(0, 3, 1)];
      expect(BridgesRules.canAdd(plus, down, 1, 2), isFalse);
      expect(BridgesRules.canAdd(plus, down, 2, 1), isFalse);
      expect(BridgesRules.canAdd(plus, down, 0, 3), isTrue);
    });

    test('cycle: 0 -> 1 -> 2 -> 0 and the result is sorted', () {
      var links = <BridgesLink>[const BridgesLink(4, 5, 1)];
      links = BridgesRules.cycle(small, links, 2, 3);
      expect(links, [const BridgesLink(2, 3, 1), const BridgesLink(4, 5, 1)]);
      links = BridgesRules.cycle(small, links, 0, 1);
      expect(links.map((l) => l.a), [0, 2, 4]); // sorted by (a, b)
      links = BridgesRules.cycle(small, links, 3, 2); // either order
      expect(links.firstWhere((l) => l.a == 2).count, 2);
      links = BridgesRules.cycle(small, links, 2, 3);
      expect(links.any((l) => l.a == 2 && l.b == 3), isFalse);
      expect(links, [const BridgesLink(0, 1, 1), const BridgesLink(4, 5, 1)]);
      // The input is never modified.
      final before = <BridgesLink>[const BridgesLink(0, 1, 1)];
      BridgesRules.cycle(small, before, 0, 1);
      expect(before, [const BridgesLink(0, 1, 1)]);
      // Three taps on one pair come back to the start.
      var x = <BridgesLink>[];
      for (var i = 0; i < 3; i++) {
        x = BridgesRules.cycle(small, x, 0, 2);
        expect(x.length, i < 2 ? 1 : 0);
        if (i < 2) expect(x.single.count, i + 1);
      }
    });

    test('cycle: blocked by a crossing link, or not a visible pair', () {
      final links = [const BridgesLink(0, 3, 1)];
      final r = BridgesRules.cycle(plus, links, 1, 2);
      expect(identical(r, links), isTrue);
      expect(r, [const BridgesLink(0, 3, 1)]);
      // Cycling the existing link still works.
      expect(BridgesRules.cycle(plus, links, 0, 3).single.count, 2);
      // No line of sight: unchanged.
      final none = <BridgesLink>[];
      expect(identical(BridgesRules.cycle(small, none, 0, 5), none), isTrue);
      // Removing the crossing link frees the other one.
      expect(BridgesRules.cycle(plus, const [], 1, 2), [
        const BridgesLink(1, 2, 1),
      ]);
    });

    test('degrees, overfull', () {
      final links = [
        const BridgesLink(0, 1, 2),
        const BridgesLink(0, 2, 1),
        const BridgesLink(2, 3, 2),
      ];
      expect(BridgesRules.degrees(small, links), [3, 2, 3, 2, 0, 0]);
      expect(BridgesRules.degrees(small, const []), [0, 0, 0, 0, 0, 0]);
      expect(BridgesRules.overfull(small, links, 0), isTrue); // 3 > 2
      expect(BridgesRules.overfull(small, links, 1), isFalse); // 2 <= 3
      expect(BridgesRules.overfull(small, links, 2), isFalse); // 3 <= 4
      expect(BridgesRules.overfull(small, links, 4), isFalse);
      // Exactly its number is not over.
      expect(BridgesRules.overfull(small, small.solution, 0), isFalse);
    });
  });

  group('connected and solved', () {
    test('connected: one group through the links', () {
      expect(BridgesRules.connected(small, small.solution), isTrue);
      expect(BridgesRules.connected(small, const []), isFalse);
      final tree = [
        const BridgesLink(0, 1, 1),
        const BridgesLink(1, 3, 1),
        const BridgesLink(2, 3, 1),
        const BridgesLink(2, 4, 1),
        const BridgesLink(4, 5, 1),
      ];
      expect(BridgesRules.connected(small, tree), isTrue);
      expect(BridgesRules.connected(small, tree.sublist(0, 4)), isFalse);
      // A single island is a group by itself.
      expect(
        BridgesRules.connected(makePuzzle(3, 3, [(1, 1, 1)]), const []),
        isTrue,
      );
    });

    test('isSolved: the stored answer and nothing less or more', () {
      expect(BridgesRules.isSolved(small, small.solution), isTrue);
      expect(
        BridgesRules.isSolved(small, small.solution.reversed.toList()),
        isTrue,
      );
      expect(BridgesRules.isSolved(small, const []), isFalse);
      for (var i = 0; i < small.solution.length; i++) {
        final partial = [...small.solution]..removeAt(i);
        expect(
          BridgesRules.isSolved(small, partial),
          isFalse,
          reason: 'without #$i',
        );
        // One bridge more on any link is over-full (no puzzle link has room).
        final l = small.solution[i];
        final more = [
          for (final x in small.solution)
            if (x == l) BridgesLink(x.a, x.b, 3 - x.count) else x,
        ];
        expect(
          BridgesRules.isSolved(small, more),
          isFalse,
          reason: 'changed #$i',
        );
      }
      // Not a visible pair.
      expect(
        BridgesRules.isSolved(small, [
          ...small.solution,
          const BridgesLink(0, 5, 1),
        ]),
        isFalse,
      );
      // The same pair listed twice.
      expect(
        BridgesRules.isSolved(small, [
          ...small.solution,
          const BridgesLink(0, 1, 1),
        ]),
        isFalse,
      );
    });

    test('isSolved: degrees right but not connected is not solved', () {
      final ring = ringPuzzle();
      expect(BridgesRules.isSolved(ring, ring.solution), isTrue);
      // Double bridges on two opposite sides give every island 2 — two separate pairs.
      final split = [const BridgesLink(0, 1, 2), const BridgesLink(2, 3, 2)];
      expect(BridgesRules.degrees(ring, split), [2, 2, 2, 2]);
      expect(BridgesRules.connected(ring, split), isFalse);
      expect(BridgesRules.isSolved(ring, split), isFalse);
      // So are the other pair of opposite sides.
      expect(
        BridgesRules.isSolved(ring, [
          const BridgesLink(0, 2, 2),
          const BridgesLink(1, 3, 2),
        ]),
        isFalse,
      );
    });

    test('isSolved: crossing bridges are never a solution', () {
      // Needs that only the two doubled chords (which cross) would satisfy.
      final p = chordsPuzzle(const [2, 4, 2, 4, 4, 2, 4, 2]);
      final crossing = bruteForce(p, forbidCrossing: false).single;
      expect(BridgesRules.degrees(p, crossing), [2, 4, 2, 4, 4, 2, 4, 2]);
      expect(BridgesRules.connected(p, crossing), isTrue);
      expect(BridgesRules.isSolved(p, crossing), isFalse);
      // ... while the edge ring on the all-2 board is fine.
      final ring = chordsPuzzle(const [2, 2, 2, 2, 2, 2, 2, 2]);
      final answer = bruteForce(ring).single;
      expect(BridgesRules.isSolved(ring, answer), isTrue);
    });

    test(
      'isSolved holds for every generated puzzle and not after removing a link',
      () {
        for (var seed = 0; seed < 20; seed++) {
          final p = BridgesGenerator.generate(
            const BridgesParams(rows: 7, cols: 7, islands: 12, doubles: .3),
            seed,
          );
          expect(BridgesRules.isSolved(p, p.solution), isTrue);
          expect(BridgesRules.isSolved(p, p.solution.sublist(1)), isFalse);
        }
      },
    );
  });

  group('wrongLinks', () {
    test(
      'by pair: unknown pairs and larger counts are wrong, smaller are not',
      () {
        // A visible pair the solution does not use.
        final (p, pair) = puzzleWithUnusedPair();
        final stray = BridgesLink(pair.$1, pair.$2, 1);
        expect(BridgesRules.wrongLinks(p, p.solution), isEmpty);
        expect(BridgesRules.wrongLinks(p, const []), isEmpty);
        expect(BridgesRules.wrongLinks(p, [stray]), [stray]);
        expect(BridgesRules.wrongLinks(p, [...p.solution, stray]), [stray]);
        // Over by one, and under by one (a double placed as single).
        final single = p.solution.firstWhere((l) => l.count == 1);
        final double = p.solution.firstWhere((l) => l.count == 2);
        final over = single.withCount(2);
        final under = double.withCount(1);
        expect(BridgesRules.wrongLinks(p, [over]), [over]);
        expect(BridgesRules.wrongLinks(p, [under]), isEmpty);
        // Input order is kept.
        expect(BridgesRules.wrongLinks(p, [over, under, stray]), [over, stray]);
        expect(BridgesRules.wrongLinks(p, [stray, over]), [stray, over]);
      },
    );
  });

  group('hints', () {
    test('first hint: an island with one neighbour', () {
      // Island 5 (need 1) can only reach island 4.
      final h = BridgesRules.hint(small, const [])!;
      expect(h.kind, BridgesHintKind.onlyNeighbour);
      expect((h.island, h.a, h.b, h.count), (5, 4, 5, 1));
    });

    test('fullIsland: every open neighbour gets the most it can take', () {
      // Islands 4 and 5 are done; island 3 needs 4 and has two open neighbours (1, 2).
      final links = [const BridgesLink(2, 4, 1), const BridgesLink(4, 5, 1)];
      final h = BridgesRules.hint(small, links)!;
      expect(h.kind, BridgesHintKind.fullIsland);
      expect(h.island, 3);
      expect((h.a, h.b, h.count), (1, 3, 2));
    });

    test('onlyNeighbour counts what the island still lacks', () {
      // After the bridge 4–5, island 4 still needs one more and can only use 2–4.
      final h = BridgesRules.hint(small, [const BridgesLink(4, 5, 1)])!;
      expect(h.kind, BridgesHintKind.onlyNeighbour);
      expect((h.island, h.a, h.b, h.count), (4, 2, 4, 1));
    });

    test('forced: at least one bridge each way', () {
      final p = forcedPuzzle();
      // Island 3 (need 1) only reaches island 1, so that bridge comes first ...
      final first = BridgesRules.hint(p, const [])!;
      expect(first.kind, BridgesHintKind.onlyNeighbour);
      expect((first.island, first.a, first.b, first.count), (3, 1, 3, 1));
      // ... and then island 0 needs 3 with two neighbours that can take 2 each: it
      // cannot give both of them 2 (that would be 4), so each gets at least 1.
      final h = BridgesRules.hint(p, [const BridgesLink(1, 3, 1)])!;
      expect(h.kind, BridgesHintKind.forced);
      expect((h.island, h.a, h.b, h.count), (0, 0, 1, 1));
      expect(BridgesSolver.countSolutions(p), 1);
    });

    test('forced by a crossing: a drawn bridge blocks a neighbour', () {
      final p = crossingPuzzle();
      expect(BridgesSolver.countSolutions(p), 1);
      // With the row-2 bridge drawn, island 1 cannot reach island 6 any more, so
      // islands 0 and 2 must give it its three bridges between them: one each at least.
      final h = BridgesRules.hint(p, [const BridgesLink(3, 4, 2)])!;
      expect(h.kind, BridgesHintKind.forced);
      expect(h.why, BridgesForcedWhy.crossing);
      expect((h.island, h.a, h.b, h.count), (1, 0, 1, 1));
      // The other kinds carry no reason.
      final before = BridgesRules.hint(p, const [])!;
      expect(before.why, isNull);
    });

    test('forced to avoid cutting islands off', () {
      final p = sealedPuzzle();
      expect(BridgesSolver.countSolutions(p), 1);
      // Two double bridges at the top: a double down the right side would close the
      // group off from the rest, so the way on goes through island 2 instead.
      final links = [const BridgesLink(0, 1, 2), const BridgesLink(1, 3, 2)];
      final h = BridgesRules.hint(p, links)!;
      expect(h.kind, BridgesHintKind.forced);
      expect(h.why, BridgesForcedWhy.cutOff);
      expect((h.island, h.a, h.b, h.count), (2, 2, 3, 1));
    });

    test('the plain forced step is about the neighbours', () {
      final h = BridgesRules.hint(forcedPuzzle(), [
        const BridgesLink(1, 3, 1),
      ])!;
      expect(h.why, BridgesForcedWhy.neighbours);
    });

    test(
      'solved board has no hint; a stray bridge or extra count is hinted',
      () {
        expect(BridgesRules.hint(small, small.solution), isNull);
        // Every solution link placed, one of them with one bridge too many.
        final over = [
          for (final l in small.solution)
            if (l.a == 4) l.withCount(2) else l,
        ];
        final h = BridgesRules.hint(small, over)!;
        expect(h.kind, BridgesHintKind.solution);
        expect((h.a, h.b, h.count), (4, 5, 1));
        // Every solution link plus a pair the solution does not use: remove it (count 0).
        final (p, stray) = puzzleWithUnusedPair();
        final r = BridgesRules.hint(p, [
          ...p.solution,
          BridgesLink(stray.$1, stray.$2, 1),
        ])!;
        expect(
          (r.a, r.b, r.count, r.kind),
          (stray.$1, stray.$2, 0, BridgesHintKind.solution),
        );
      },
    );

    test('wrong bridges are ignored: the hint is still part of the answer', () {
      final wrong = [const BridgesLink(4, 5, 2), const BridgesLink(0, 2, 2)];
      final h = BridgesRules.hint(small, wrong)!;
      final sol = {for (final l in small.solution) (l.a, l.b): l.count};
      expect(sol[(h.a, h.b)], isNotNull);
      expect(h.count, lessThanOrEqualTo(sol[(h.a, h.b)]!));
    });

    test('applying hints from empty solves every puzzle (and they are teaching steps)', () {
      const sizes = [(5, 6), (6, 9), (7, 12), (8, 16), (9, 20)];
      final kinds = <BridgesHintKind, int>{};
      for (final (n, islands) in sizes) {
        for (var seed = 0; seed < 25; seed++) {
          final p = BridgesGenerator.generate(
            BridgesParams(
              rows: n,
              cols: n,
              islands: islands,
              doubles: (seed % 6) / 10,
            ),
            seed,
          );
          final truth = {for (final l in p.solution) (l.a, l.b): l.count};
          // A hint can lift a double link one bridge at a time, but each step adds
          // at least one bridge, so the loop must end within this many.
          final totalBridges = p.solution.fold(0, (t, l) => t + l.count);
          var links = <BridgesLink>[];
          var steps = 0;
          while (!BridgesRules.isSolved(p, links)) {
            expect(
              steps++,
              lessThan(totalBridges),
              reason: 'size $n seed $seed',
            );
            final h = BridgesRules.hint(p, links)!;
            expect(h.a, lessThan(h.b));
            expect(
              truth[(h.a, h.b)],
              isNotNull,
              reason: '$h is not in the answer',
            );
            expect(
              h.count,
              lessThanOrEqualTo(truth[(h.a, h.b)]!),
              reason: '$h',
            );
            expect(
              BridgesRules.degrees(p, links)[h.island],
              lessThan(p.islands[h.island].need),
              reason: '$h',
            );
            kinds[h.kind] = (kinds[h.kind] ?? 0) + 1;
            links = setLink(links, h.a, h.b, h.count);
          }
          expect(BridgesRules.hint(p, links), isNull);
          expect(links, p.solution);
        }
      }
      // Most steps are explainable; the plain "solution" fallback is rare.
      final total = kinds.values.fold(0, (a, b) => a + b);
      expect(kinds[BridgesHintKind.onlyNeighbour], greaterThan(total ~/ 3));
      expect(kinds[BridgesHintKind.fullIsland], greaterThan(0));
      expect(kinds[BridgesHintKind.forced], greaterThan(0));
      expect(kinds[BridgesHintKind.solution] ?? 0, lessThan(total ~/ 20));
    });

    test('reasoning never contradicts the answer, even from messy boards', () {
      final rng = Random(5);
      var reasoned = 0;
      for (var seed = 0; seed < 40; seed++) {
        final p = BridgesGenerator.generate(
          BridgesParams(
            rows: 7,
            cols: 7,
            islands: 12,
            doubles: (seed % 6) / 10,
          ),
          seed + 100,
        );
        final truth = {for (final l in p.solution) (l.a, l.b): l.count};
        final unused = BridgesRules.pairs(p)
            .where((x) => !truth.containsKey(x))
            .toList();
        for (var t = 0; t < 12; t++) {
          // A random part of the answer, some of it under-built, plus junk.
          final links = <BridgesLink>[];
          for (final l in p.solution) {
            if (rng.nextInt(3) == 0) continue;
            links.add(l.count == 2 && rng.nextBool() ? l.withCount(1) : l);
          }
          final good = [...links];
          if (unused.isNotEmpty && rng.nextBool()) {
            final x = unused[rng.nextInt(unused.length)];
            links.add(BridgesLink(x.$1, x.$2, 1 + rng.nextInt(2)));
          }
          if (rng.nextInt(4) == 0 && links.isNotEmpty) {
            final i = rng.nextInt(links.length);
            links[i] = links[i].withCount(2);
          }
          final have = {for (final l in good) (l.a, l.b): l.count};
          final r = BridgesHintEngine.reason(p, links);
          if (r != null) {
            reasoned++;
            expect(truth[(r.a, r.b)], isNotNull, reason: 'seed $seed: $r');
            expect(
              r.count,
              lessThanOrEqualTo(truth[(r.a, r.b)]!),
              reason: 'seed $seed: $r',
            );
            expect(
              r.count,
              greaterThan(have[(r.a, r.b)] ?? 0),
              reason: 'seed $seed: $r',
            );
            expect(r.kind, isNot(BridgesHintKind.solution));
          }
          final h = BridgesRules.hint(p, links);
          if (!BridgesRules.isSolved(p, links)) {
            expect(h, isNotNull);
            if (h!.count == 0) {
              expect(truth.containsKey((h.a, h.b)), isFalse);
            } else {
              expect(h.count, lessThanOrEqualTo(truth[(h.a, h.b)]!));
            }
          }
        }
      }
      expect(reasoned, greaterThan(100));
    });
  });
}
