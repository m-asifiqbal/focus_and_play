// Thread generator tests: validity, uniqueness, determinism, JSON and speed for every
// size the app uses.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/common/hamiltonian.dart';
import 'package:focus_and_play_mindgame/games/thread/thread.dart';

const _sizes = [4, 5, 6, 7, 8];
const _seeds = 25;

void _expectValid(ThreadPuzzle p, String why) {
  final n = p.size;
  expect(isHamiltonianPath(p.solution, n, n), isTrue, reason: why);
  expect(p.cellCount, n * n, reason: why);
  expect(p.numbers[p.solution.first], 1, reason: why);
  expect(p.numbers[p.solution.last], p.maxNumber, reason: why);
  expect(p.maxNumber, p.numbers.length, reason: why);
  // Numbers appear along the solution exactly as 1, 2, …, K.
  final along = [
    for (final c in p.solution)
      if (p.numbers[c] != null) p.numbers[c]!,
  ];
  expect(along, [for (var i = 1; i <= p.maxNumber; i++) i], reason: why);
}

void main() {
  test('every size × many seeds gives a valid, unique puzzle', () {
    for (final n in _sizes) {
      for (var seed = 0; seed < _seeds; seed++) {
        final why = 'size $n seed $seed';
        final p = ThreadGenerator.generate(ThreadParams(size: n), seed);
        _expectValid(p, why);
        expect(
          ThreadSolver.countSolutions(n, p.numbers),
          1,
          reason: '$why: not unique',
        );
        expect(ThreadRules.isSolved(p, p.solution), isTrue, reason: why);
      }
    }
  });

  test('extra numbers are added on top and keep the puzzle unique', () {
    for (final n in _sizes) {
      for (var seed = 0; seed < 5; seed++) {
        final hard = ThreadGenerator.generate(ThreadParams(size: n), seed);
        final easy = ThreadGenerator.generate(
          ThreadParams(size: n, extraNumbers: 3),
          seed,
        );
        final why = 'size $n seed $seed';
        _expectValid(easy, why);
        expect(easy.solution, hard.solution, reason: why);
        expect(easy.maxNumber, hard.maxNumber + 3, reason: why);
        for (final c in hard.numbers.keys) {
          expect(easy.numbers.containsKey(c), isTrue, reason: why);
        }
        expect(ThreadSolver.countSolutions(n, easy.numbers), 1, reason: why);
      }
    }
  });

  test('same seed gives identical JSON; different seeds differ', () {
    for (final n in _sizes) {
      final a = ThreadGenerator.generate(ThreadParams(size: n), 42).toJson();
      final b = ThreadGenerator.generate(ThreadParams(size: n), 42).toJson();
      final c = ThreadGenerator.generate(ThreadParams(size: n), 43).toJson();
      expect(jsonEncode(a), jsonEncode(b));
      expect(jsonEncode(a), isNot(jsonEncode(c)));
    }
  });

  test('JSON round trip keeps everything', () {
    for (final n in _sizes) {
      final p = ThreadGenerator.generate(ThreadParams(size: n), 7);
      final text = jsonEncode(p.toJson());
      final q = ThreadPuzzle.fromJson(jsonDecode(text) as Map<String, Object?>);
      expect(jsonEncode(q.toJson()), text);
      expect(q.size, p.size);
      expect(q.numbers, p.numbers);
      expect(q.solution, p.solution);
      expect(q.maxNumber, p.maxNumber);
    }
  });

  test('solver counts several solutions on an under-numbered board', () {
    // Two corners of one side on 4×4 with nothing in between: many paths.
    expect(ThreadSolver.countSolutions(4, {0: 1, 3: 2}), 2);
    expect(ThreadSolver.countSolutions(4, {0: 1, 3: 2}, maxSolutions: 5), 5);
    // Opposite corners share a colour on an even board: no path can join them.
    expect(ThreadSolver.countSolutions(4, {0: 1, 15: 2}), 0);
  });

  test('generation is fast for the largest sizes', () {
    final timings = <int, String>{};
    for (final n in _sizes) {
      // Warm up the JIT so the first size doesn't pay for compilation.
      ThreadGenerator.generate(ThreadParams(size: n), 1000);
      final sw = Stopwatch();
      var worst = 0;
      const runs = 20;
      for (var seed = 0; seed < runs; seed++) {
        final t0 = sw.elapsedMicroseconds;
        sw.start();
        ThreadGenerator.generate(ThreadParams(size: n), seed);
        sw.stop();
        final us = sw.elapsedMicroseconds - t0;
        if (us > worst) worst = us;
      }
      final avgMs = sw.elapsedMicroseconds / runs / 1000;
      timings[n] =
          'avg ${avgMs.toStringAsFixed(1)} ms, '
          'max ${(worst / 1000).toStringAsFixed(1)} ms';
      if (n >= 7) expect(avgMs, lessThan(150), reason: 'size $n');
    }
    // ignore: avoid_print
    print('Thread generation: $timings');
  });
}
