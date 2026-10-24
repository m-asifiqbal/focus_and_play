// Twist generator: every size and many seeds give valid boards whose words tile the grid
// and can each be traced in exactly one way; same seed → same board; JSON round trip.

// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/twist/twist.dart';

const _sizes = [
  TwistParams(rows: 4, cols: 4, minLen: 4, maxLen: 6),
  TwistParams(rows: 4, cols: 5, minLen: 4, maxLen: 6),
  TwistParams(rows: 5, cols: 5, minLen: 4, maxLen: 7),
  TwistParams(rows: 5, cols: 6, minLen: 4, maxLen: 7),
  TwistParams(rows: 6, cols: 6, minLen: 4, maxLen: 6),
  TwistParams(rows: 6, cols: 6, minLen: 4, maxLen: 8),
];

/// Independent tracing counter (edge steps, no reuse), capped at 2.
int _tracings(TwistPuzzle p, String word) {
  var count = 0;
  final used = List<bool>.filled(p.cellCount, false);
  void walk(int cell, int k) {
    if (count >= 2) return;
    if (k == word.length - 1) {
      count++;
      return;
    }
    used[cell] = true;
    for (final nb in neighboursOf(cell, p.rows, p.cols)) {
      if (!used[nb] && p.letters[nb] == word[k + 1]) walk(nb, k + 1);
    }
    used[cell] = false;
  }

  for (var c = 0; c < p.cellCount; c++) {
    if (p.letters[c] == word[0]) walk(c, 0);
  }
  return count;
}

void _expectValid(TwistPuzzle p, TwistParams params, String why) {
  expect(p.rows, params.rows, reason: why);
  expect(p.cols, params.cols, reason: why);
  expect(p.letters, hasLength(p.cellCount), reason: why);
  for (final l in p.letters) {
    expect(RegExp(r'^[A-Z]$').hasMatch(l), isTrue, reason: why);
  }
  expect(kWordThemes.containsKey(p.theme), isTrue, reason: why);
  final themeWords = kWordThemes[p.theme]!;
  final owner = List<int>.filled(p.cellCount, -1);
  final seen = <String>{};
  for (var i = 0; i < p.words.length; i++) {
    final w = p.words[i];
    final at = '$why word ${w.word}';
    expect(seen.add(w.word), isTrue, reason: '$at twice');
    expect(themeWords, contains(w.word), reason: at);
    expect(
      w.length,
      inInclusiveRange(params.minLen, params.maxLen),
      reason: at,
    );
    expect(w.cells, hasLength(w.length), reason: at);
    for (var k = 0; k < w.cells.length; k++) {
      final c = w.cells[k];
      expect(c, inInclusiveRange(0, p.cellCount - 1), reason: at);
      expect(owner[c], -1, reason: '$at overlaps');
      owner[c] = i;
      expect(p.letters[c], w.word[k], reason: at);
      if (k > 0) {
        expect(
          isOrthogonalNeighbour(w.cells[k - 1], c, p.cols),
          isTrue,
          reason: '$at not a path',
        );
      }
    }
    expect(_tracings(p, w.word), 1, reason: '$at has another tracing');
    if (i > 0) {
      final prev = p.words[i - 1];
      final ordered =
          prev.length < w.length ||
          (prev.length == w.length && prev.cells.first < w.cells.first);
      expect(ordered, isTrue, reason: '$why words not sorted');
    }
  }
  expect(
    owner.contains(-1),
    isFalse,
    reason: '$why: words do not tile the board',
  );
}

void main() {
  test('many seeds x every size give valid, uniquely readable boards', () {
    for (final params in _sizes) {
      for (var seed = 0; seed < 60; seed++) {
        final p = TwistGenerator.generate(params, seed);
        _expectValid(p, params, '$params seed $seed');
      }
    }
  });

  test('same seed gives the same board, other seeds differ', () {
    for (final params in _sizes) {
      final a = TwistGenerator.generate(params, 42).toJson();
      final b = TwistGenerator.generate(params, 42).toJson();
      expect(a, b);
      final others = {
        for (var s = 0; s < 10; s++)
          jsonEncode(TwistGenerator.generate(params, s).toJson()),
      };
      expect(others.length, greaterThan(8), reason: '$params');
    }
  });

  test('JSON round trip through a string keeps the board', () {
    for (final params in _sizes) {
      final p = TwistGenerator.generate(params, 7);
      final decoded =
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      final back = TwistPuzzle.fromJson(decoded);
      expect(back.toJson(), p.toJson());
      _expectValid(back, params, 'round trip $params');
    }
  });

  test('themes vary across seeds', () {
    final themes = {
      for (var s = 0; s < 60; s++)
        TwistGenerator.generate(_sizes.last, s).theme,
    };
    expect(themes.length, greaterThanOrEqualTo(8));
  });

  test('impossible params are rejected', () {
    expect(
      () => TwistGenerator.generate(
        const TwistParams(rows: 4, cols: 4, minLen: 3, maxLen: 6),
        0,
      ),
      throwsArgumentError,
    );
    expect(
      () => TwistGenerator.generate(
        const TwistParams(rows: 6, cols: 6, minLen: 4, maxLen: 9),
        0,
      ),
      throwsArgumentError,
    );
    // 9 cells can't be cut into words of 5..8 letters.
    expect(
      () => TwistGenerator.generate(
        const TwistParams(rows: 3, cols: 3, minLen: 5, maxLen: 8),
        0,
      ),
      throwsArgumentError,
    );
  });

  test('6x6 generation averages well under 150 ms', () {
    const params = TwistParams(rows: 6, cols: 6, minLen: 4, maxLen: 8);
    TwistGenerator.generate(params, 999); // warm-up (JIT)
    final sw = Stopwatch()..start();
    for (var s = 0; s < 20; s++) {
      TwistGenerator.generate(params, 1000 + s);
    }
    final avgMs = sw.elapsedMicroseconds / 20 / 1000;
    print(
      'Twist 6x6 (4..8): ${avgMs.toStringAsFixed(2)} ms average over 20 seeds',
    );
    expect(avgMs, lessThan(150));
  });
}
