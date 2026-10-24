// Word bank rules: enough themes and words, clean spelling, a healthy length spread.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

void main() {
  test('at least 10 themes with at least 45 words each', () {
    expect(kWordThemes.length, greaterThanOrEqualTo(10));
    for (final e in kWordThemes.entries) {
      expect(e.value.length, greaterThanOrEqualTo(45), reason: e.key);
    }
  });

  test('words are upper-case A-Z, 4..8 letters, unique, not palindromes', () {
    final shape = RegExp(r'^[A-Z]{4,8}$');
    for (final e in kWordThemes.entries) {
      final seen = <String>{};
      for (final w in e.value) {
        expect(shape.hasMatch(w), isTrue, reason: '${e.key}: $w');
        expect(seen.add(w), isTrue, reason: '${e.key}: duplicate $w');
        expect(w.split('').reversed.join(), isNot(w), reason: '${e.key}: $w');
      }
    }
  });

  test('no word is just another word of its theme plus S', () {
    for (final e in kWordThemes.entries) {
      final words = e.value.toSet();
      for (final w in e.value) {
        expect(words.contains('${w}S'), isFalse, reason: '${e.key}: $w');
      }
    }
  });

  test('every theme has a healthy spread of lengths', () {
    for (final e in kWordThemes.entries) {
      final byLen = <int, int>{};
      for (final w in e.value) {
        byLen[w.length] = (byLen[w.length] ?? 0) + 1;
      }
      // A 6×6 board (4..8) needs up to 9 four-letter or 4 eight-letter words, plus
      // spares for the generator's word swaps.
      expect(byLen[4], greaterThanOrEqualTo(12), reason: e.key);
      expect(byLen[5], greaterThanOrEqualTo(10), reason: e.key);
      expect(byLen[6], greaterThanOrEqualTo(10), reason: e.key);
      expect(byLen[7], greaterThanOrEqualTo(8), reason: e.key);
      expect(byLen[8], greaterThanOrEqualTo(8), reason: e.key);
    }
  });
}
