// Twist rules: tracing (canAppend), matching, "right word, other tiles", solved, hints.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/twist/twist.dart';

/// Hand-made 2×4 board where BEAR is readable on both rows:
///   B E A R      word 0: BEAR  cells 0 1 2 3
///   B E A R      word 1: RAEB  cells 7 6 5 4
TwistPuzzle _twoBears() => TwistPuzzle.fromJson({
  'rows': 2,
  'cols': 4,
  'theme': 'Animals',
  'letters': ['B', 'E', 'A', 'R', 'B', 'E', 'A', 'R'],
  'words': [
    {
      'word': 'BEAR',
      'cells': [0, 1, 2, 3],
    },
    {
      'word': 'RAEB',
      'cells': [7, 6, 5, 4],
    },
  ],
});

void main() {
  const params = TwistParams(rows: 6, cols: 6, minLen: 4, maxLen: 8);

  test('canAppend: start anywhere free, then only fresh edge neighbours', () {
    final p = TwistGenerator.generate(params, 3);
    final w0 = p.words[0].cells.toSet();
    for (var c = 0; c < p.cellCount; c++) {
      expect(TwistRules.canAppend(p, const [], const {}, c), isTrue);
      expect(TwistRules.canAppend(p, const [], {0}, c), !w0.contains(c));
    }
    expect(TwistRules.canAppend(p, const [], const {}, -1), isFalse);
    expect(TwistRules.canAppend(p, const [], const {}, p.cellCount), isFalse);

    final traced = [14];
    for (var c = 0; c < p.cellCount; c++) {
      expect(
        TwistRules.canAppend(p, traced, const {}, c),
        isOrthogonalNeighbour(14, c, p.cols),
        reason: 'cell $c',
      );
    }
    // No diagonal, no reuse.
    expect(TwistRules.canAppend(p, [14, 15], const {}, 14), isFalse);
    expect(TwistRules.canAppend(p, [14], const {}, 21), isFalse);
  });

  test('canAppend never enters a found word', () {
    final p = TwistGenerator.generate(params, 5);
    final found = {0, 1};
    for (final i in found) {
      for (final c in p.words[i].cells) {
        for (final nb in neighboursOf(c, p.rows, p.cols)) {
          expect(TwistRules.canAppend(p, [nb], found, c), isFalse);
        }
      }
    }
  });

  test('tracing every word in order matches it and solves the board', () {
    for (var seed = 0; seed < 20; seed++) {
      final p = TwistGenerator.generate(params, seed);
      final found = <int>{};
      for (var i = 0; i < p.words.length; i++) {
        final traced = <int>[];
        for (final c in p.words[i].cells) {
          expect(TwistRules.canAppend(p, traced, found, c), isTrue);
          traced.add(c);
        }
        expect(TwistRules.match(p, traced, found), i);
        expect(TwistRules.sameWordOtherCells(p, traced, found), isNull);
        // Backwards is not a match.
        expect(TwistRules.match(p, traced.reversed.toList(), found), isNull);
        expect(TwistRules.isSolved(p, found), isFalse);
        found.add(i);
        expect(
          TwistRules.match(p, traced, found),
          isNull,
          reason: 'found twice',
        );
      }
      expect(TwistRules.isSolved(p, found), isTrue);
    }
  });

  test('a prefix or partial word does not match', () {
    final p = TwistGenerator.generate(params, 9);
    final cells = p.words.last.cells;
    expect(TwistRules.match(p, cells.sublist(0, cells.length - 1), {}), isNull);
    expect(TwistRules.match(p, const [], {}), isNull);
  });

  test('sameWordOtherCells spots the right word on other tiles', () {
    final p = _twoBears();
    expect(TwistRules.match(p, [0, 1, 2, 3], {}), 0);
    expect(TwistRules.match(p, [4, 5, 6, 7], {}), isNull);
    expect(TwistRules.sameWordOtherCells(p, [4, 5, 6, 7], {}), 0);
    expect(TwistRules.sameWordOtherCells(p, [0, 1, 2, 3], {}), isNull);
    // Once BEAR is found it is no longer suggested.
    expect(TwistRules.sameWordOtherCells(p, [4, 5, 6, 7], {0}), isNull);
    // RAEB read along the top row.
    expect(TwistRules.sameWordOtherCells(p, [3, 2, 1, 0], {}), 1);
    expect(TwistRules.sameWordOtherCells(p, const [], {}), isNull);
  });

  test(
    'hint: shortest word first, one more letter per call, then the next',
    () {
      final p = TwistGenerator.generate(params, 11);
      final revealed = <int, int>{};
      final found = <int>{};
      // Words are sorted shortest first, so hints walk the list in order.
      for (var i = 0; i < p.words.length; i++) {
        for (var k = 1; k <= p.words[i].length; k++) {
          final h = TwistRules.hint(p, found, revealed);
          expect(h, TwistHint(wordIndex: i, lettersShown: k));
          revealed[h.wordIndex] = h.lettersShown;
        }
      }
      // Everything spelled out: keep pointing at the shortest unfound word.
      expect(
        TwistRules.hint(p, found, revealed),
        TwistHint(wordIndex: 0, lettersShown: p.words[0].length),
      );
    },
  );

  test('hint skips found words and continues a half-revealed word', () {
    final p = TwistGenerator.generate(params, 12);
    expect(
      TwistRules.hint(p, {0}, const {}),
      const TwistHint(wordIndex: 1, lettersShown: 1),
    );
    expect(
      TwistRules.hint(p, {0}, {1: 2}),
      const TwistHint(wordIndex: 1, lettersShown: 3),
    );
    // A stale entry for a found word is ignored.
    expect(
      TwistRules.hint(p, {0}, {0: 2}),
      const TwistHint(wordIndex: 1, lettersShown: 1),
    );
    final all = {for (var i = 0; i < p.words.length; i++) i};
    expect(() => TwistRules.hint(p, all, const {}), throwsStateError);
  });

  test('hint orders by length even when the word list is not sorted', () {
    final p = TwistPuzzle.fromJson({
      'rows': 3,
      'cols': 3,
      'theme': 'Animals',
      'letters': ['T', 'I', 'G', 'G', 'R', 'E', 'O', 'A', 'T'],
      'words': [
        {
          'word': 'TIGER',
          'cells': [0, 1, 2, 5, 4],
        },
        {
          'word': 'GOAT',
          'cells': [3, 6, 7, 8],
        },
      ],
    });
    expect(
      TwistRules.hint(p, const {}, const {}),
      const TwistHint(wordIndex: 1, lettersShown: 1),
    );
  });
}
