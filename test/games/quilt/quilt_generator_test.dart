// Quilt generator tests: validity, uniqueness, determinism, JSON and speed for every
// size and area limit the app uses.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';

const _sizes = [5, 6, 7, 8];
const _maxAreas = [6, 9, 12];
const _seeds = 25;

/// Difficulty mixes: area only, some shapes, some shape-only, all shape-only.
const _mixes = [(0.0, 0.0), (0.5, 0.0), (0.6, 0.5), (1.0, 1.0)];

void _expectValid(QuiltPuzzle p, QuiltParams params, String why) {
  final n = p.size;
  expect(p.clues.length, p.solution.length, reason: why);
  // Patches tile the grid exactly.
  final owner = List<int>.filled(n * n, -1);
  for (var i = 0; i < p.solution.length; i++) {
    final r = p.solution[i];
    expect(r.isInside(n), isTrue, reason: '$why: $r outside');
    expect(r.area, inInclusiveRange(2, params.maxArea), reason: '$why: $r');
    for (final c in r.cells(n)) {
      expect(owner[c], -1, reason: '$why: cell $c covered twice');
      owner[c] = i;
    }
  }
  expect(owner.contains(-1), isFalse, reason: '$why: gap');
  // Each patch holds exactly its own clue, and the clue describes it truthfully.
  for (var i = 0; i < p.clues.length; i++) {
    final clue = p.clues[i];
    expect(owner[clue.cell], i, reason: '$why: clue $i');
    expect(QuiltRules.clueIn(p, p.solution[i]), i, reason: why);
    expect(clue.area != null || clue.shape != null, isTrue, reason: why);
    if (clue.area != null) expect(clue.area, p.solution[i].area, reason: why);
    if (clue.shape != null) {
      expect(clue.shape, p.solution[i].shape, reason: why);
    }
    if (i > 0) expect(clue.cell, greaterThan(p.clues[i - 1].cell), reason: why);
  }
}

void main() {
  test('every size × area limit × seed gives a valid, unique puzzle', () {
    for (final n in _sizes) {
      for (final maxArea in _maxAreas) {
        for (var seed = 0; seed < _seeds; seed++) {
          final (sc, so) = _mixes[seed % _mixes.length];
          final params = QuiltParams(
            size: n,
            maxArea: maxArea,
            shapeClues: sc,
            shapeOnly: so,
          );
          final why = 'size $n maxArea $maxArea seed $seed mix ($sc, $so)';
          final p = QuiltGenerator.generate(params, seed);
          _expectValid(p, params, why);
          expect(
            QuiltSolver.countSolutions(n, p.clues),
            1,
            reason: '$why: not unique',
          );
          expect(QuiltRules.isSolved(p, p.solution), isTrue, reason: why);
        }
      }
    }
  });

  test('clue mix follows the params when no extra reveals are needed', () {
    for (final n in _sizes) {
      for (var seed = 0; seed < 10; seed++) {
        final plain = QuiltGenerator.generate(
          QuiltParams(size: n, maxArea: 8),
          seed,
        );
        expect(
          plain.clues.every((c) => c.area != null && c.shape == null),
          isTrue,
        );
        final mixed = QuiltGenerator.generate(
          QuiltParams(size: n, maxArea: 8, shapeClues: 0.5, shapeOnly: 0.5),
          seed,
        );
        final m = mixed.clues.length;
        final shapes = (0.5 * m).round();
        final hidden = (0.5 * shapes).round();
        // Reveals only ever add information, so the counts can grow, never shrink.
        expect(
          mixed.clues.where((c) => c.shape != null).length,
          greaterThanOrEqualTo(shapes),
        );
        expect(
          mixed.clues.where((c) => c.area == null).length,
          lessThanOrEqualTo(hidden),
        );
      }
    }
  });

  test('same seed gives identical JSON; different seeds differ', () {
    for (final n in _sizes) {
      final params = QuiltParams(
        size: n,
        maxArea: 9,
        shapeClues: 0.5,
        shapeOnly: 0.5,
      );
      final a = jsonEncode(QuiltGenerator.generate(params, 42).toJson());
      final b = jsonEncode(QuiltGenerator.generate(params, 42).toJson());
      final c = jsonEncode(QuiltGenerator.generate(params, 43).toJson());
      expect(a, b);
      expect(a, isNot(c));
    }
  });

  test('JSON round trip keeps everything', () {
    for (final n in _sizes) {
      final p = QuiltGenerator.generate(
        QuiltParams(size: n, maxArea: 9, shapeClues: 0.7, shapeOnly: 0.5),
        7,
      );
      final text = jsonEncode(p.toJson());
      final q = QuiltPuzzle.fromJson(jsonDecode(text) as Map<String, Object?>);
      expect(jsonEncode(q.toJson()), text);
      expect(q.size, p.size);
      expect(q.clues, p.clues);
      expect(q.solution, p.solution);
    }
    const r = QuiltRect(row: 1, col: 2, width: 3, height: 2);
    expect(QuiltRect.fromJson(r.toJson()), r);
    const c = QuiltClue(cell: 5, shape: QuiltShape.tall);
    expect(QuiltClue.fromJson(c.toJson()), c);
    expect(c.toJson().containsKey('area'), isFalse);
  });

  test('bad params are rejected', () {
    expect(
      () => QuiltGenerator.generate(const QuiltParams(size: 1), 0),
      throwsArgumentError,
    );
    expect(
      () => QuiltGenerator.generate(const QuiltParams(size: 5, maxArea: 2), 0),
      throwsArgumentError,
    );
  });

  test('generation is fast for the largest sizes', () {
    final timings = <String, String>{};
    for (final n in _sizes) {
      for (final maxArea in [6, 12]) {
        final params = QuiltParams(
          size: n,
          maxArea: maxArea,
          shapeClues: 0.6,
          shapeOnly: 0.5,
        );
        QuiltGenerator.generate(params, 1000); // JIT warm-up
        final sw = Stopwatch();
        var worst = 0;
        const runs = 20;
        for (var seed = 0; seed < runs; seed++) {
          final t0 = sw.elapsedMicroseconds;
          sw.start();
          QuiltGenerator.generate(params, seed);
          sw.stop();
          final us = sw.elapsedMicroseconds - t0;
          if (us > worst) worst = us;
        }
        final avgMs = sw.elapsedMicroseconds / runs / 1000;
        timings['$n/$maxArea'] =
            'avg ${avgMs.toStringAsFixed(2)} ms, '
            'max ${(worst / 1000).toStringAsFixed(1)} ms';
        if (n >= 7) expect(avgMs, lessThan(150), reason: 'size $n');
      }
    }
    // ignore: avoid_print
    print('Quilt generation (size/maxArea): $timings');
  });
}
