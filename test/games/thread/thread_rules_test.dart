// Thread rules tests: move validation, solved check, next number and hints.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/thread/thread.dart';

void main() {
  final puzzles = [
    for (final n in [4, 5, 6, 7, 8])
      ThreadGenerator.generate(ThreadParams(size: n), n * 11),
  ];

  test('empty path only accepts the cell with 1', () {
    for (final p in puzzles) {
      final one = p.cellOf(1)!;
      for (var c = 0; c < p.cellCount; c++) {
        expect(ThreadRules.canAppend(p, const [], c), c == one);
      }
      expect(ThreadRules.canAppend(p, const [], -1), isFalse);
      expect(ThreadRules.canAppend(p, const [], p.cellCount), isFalse);
    }
  });

  test('the solution can be drawn step by step', () {
    for (final p in puzzles) {
      final path = <int>[];
      for (final c in p.solution) {
        expect(ThreadRules.canAppend(p, path, c), isTrue, reason: 'at $c');
        path.add(c);
        expect(ThreadRules.isSolved(p, path), path.length == p.cellCount);
      }
      expect(ThreadRules.nextNumber(p, path), p.maxNumber + 1);
      // A full path takes nothing more.
      for (var c = 0; c < p.cellCount; c++) {
        expect(ThreadRules.canAppend(p, path, c), isFalse);
      }
    }
  });

  test(
    'canAppend rejects non-neighbours, repeats, wrong numbers and an early end',
    () {
      for (final p in puzzles) {
        final n = p.size;
        // Walk the solution up to just before the second number.
        final two = p.cellOf(2)!;
        final upTo = p.solution.indexOf(two);
        final path = p.solution.sublist(0, upTo);
        expect(ThreadRules.nextNumber(p, path), 2);
        final head = path.last;
        for (var c = 0; c < p.cellCount; c++) {
          final ok = ThreadRules.canAppend(p, path, c);
          if (!isOrthogonalNeighbour(head, c, n) || path.contains(c)) {
            expect(ok, isFalse, reason: 'cell $c');
          }
          final number = p.numbers[c];
          if (number != null && number != 2) {
            expect(ok, isFalse, reason: 'number $number at $c');
          }
        }
        expect(ThreadRules.canAppend(p, path, two), isTrue);
        // The end cell is refused before the last step even when its number is next.
        final end = p.cellOf(p.maxNumber)!;
        final beforeEnd = p.solution.sublist(0, p.cellCount - 1);
        expect(ThreadRules.canAppend(p, beforeEnd, end), isTrue);
      }
    },
  );

  test('the end cell is refused while other cells are left', () {
    // 2×2: 1 at 0, 2 at 1 — the only path is 0, 2, 3, 1.
    final p = ThreadPuzzle(
      size: 2,
      numbers: {0: 1, 1: 2},
      solution: [0, 2, 3, 1],
    );
    expect(ThreadRules.canAppend(p, [0], 1), isFalse);
    expect(ThreadRules.canAppend(p, [0], 2), isTrue);
    expect(ThreadRules.canAppend(p, [0, 2, 3], 1), isTrue);
    expect(ThreadSolver.countSolutions(2, p.numbers), 1);
  });

  test('isSolved rejects broken paths', () {
    for (final p in puzzles) {
      final sol = p.solution;
      expect(ThreadRules.isSolved(p, sol), isTrue);
      expect(ThreadRules.isSolved(p, const []), isFalse);
      expect(ThreadRules.isSolved(p, sol.sublist(0, sol.length - 1)), isFalse);
      expect(ThreadRules.isSolved(p, sol.reversed.toList()), isFalse);
      // A repeated cell instead of the last one.
      expect(
        ThreadRules.isSolved(p, [...sol.sublist(0, sol.length - 1), sol[0]]),
        isFalse,
      );
      // Two cells swapped: no longer a connected path (or numbers out of order).
      final swapped = List<int>.of(sol);
      final t = swapped[1];
      swapped[1] = swapped[3];
      swapped[3] = t;
      expect(ThreadRules.isSolved(p, swapped), isFalse);
    }
    // 3×3 with 1, 2, 3 on cells 0, 1, 3 and 4 on cell 8: a Hamiltonian path from 1
    // to 4 that meets 3 before 2 is not solved.
    final p = ThreadPuzzle(
      size: 3,
      numbers: {0: 1, 1: 2, 3: 3, 8: 4},
      solution: [0, 1, 2, 5, 4, 3, 6, 7, 8],
    );
    expect(ThreadRules.isSolved(p, p.solution), isTrue);
    expect(ThreadRules.isSolved(p, [0, 3, 6, 7, 4, 1, 2, 5, 8]), isFalse);
  });

  test('hint on an empty path reveals the first cells', () {
    for (final p in puzzles) {
      final h = ThreadRules.hint(p, const []);
      expect(h.keepLength, 0);
      expect(h.next, p.solution.sublist(0, 3));
      expect(ThreadRules.hint(p, const [], reveal: 1).next, [p.solution[0]]);
    }
  });

  test('hint on a correct prefix keeps it and shows what follows', () {
    for (final p in puzzles) {
      final prefix = p.solution.sublist(0, 5);
      final h = ThreadRules.hint(p, prefix);
      expect(h.keepLength, 5);
      expect(h.next, p.solution.sublist(5, 8));
      // Near the end the reveal is clipped.
      final almost = p.solution.sublist(0, p.cellCount - 2);
      final end = ThreadRules.hint(p, almost);
      expect(end.keepLength, p.cellCount - 2);
      expect(end.next, p.solution.sublist(p.cellCount - 2));
      // On a solved path there is nothing left to reveal.
      final done = ThreadRules.hint(p, p.solution);
      expect(done.keepLength, p.cellCount);
      expect(done.next, isEmpty);
    }
  });

  test('hint on a wrong path keeps only the matching prefix', () {
    for (final p in puzzles) {
      final sol = p.solution;
      // Follow the solution for 4 cells, then step somewhere else.
      final head = sol[3];
      final wrong = neighboursOf(
        head,
        p.size,
        p.size,
      ).where((c) => c != sol[4] && !sol.sublist(0, 4).contains(c)).toList();
      if (wrong.isEmpty) continue;
      final path = [...sol.sublist(0, 4), wrong.first];
      final h = ThreadRules.hint(p, path, reveal: 2);
      expect(h.keepLength, 4);
      expect(h.next, sol.sublist(4, 6));
      // A path that starts in the wrong place keeps nothing.
      expect(ThreadRules.hint(p, [sol[1], sol[0]]).keepLength, 0);
    }
  });
}
