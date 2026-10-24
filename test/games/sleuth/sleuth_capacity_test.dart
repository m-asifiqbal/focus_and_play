// Sleuth word-bank capacity: how many same-length words a single theme offers. A level
// can never ask for more candidates than this, so the table is printed for tuning.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

void main() {
  test('maximum words in a single theme, per word length', () {
    final lines = <String>[];
    for (var len = kTwistMinWordLength; len <= kTwistMaxWordLength; len++) {
      var most = 0;
      final perTheme = <String, int>{};
      for (final e in kWordThemes.entries) {
        final n = e.value.where((w) => w.length == len).toSet().length;
        perTheme[e.key] = n;
        if (n > most) most = n;
      }
      final best = [
        for (final e in perTheme.entries)
          if (e.value == most) e.key,
      ];
      lines.add(
        'length $len: max $most (${best.join(', ')}); per theme $perTheme',
      );
      // The generator reports the same ceiling and the bank is deep enough for the
      // smallest list a level may use.
      expect(SleuthGenerator.maxCandidates(len), most);
      expect(most, greaterThanOrEqualTo(kSleuthMinCandidates));
    }
    // ignore: avoid_print
    print(
      'Sleuth: words available in one theme, by length\n${lines.join('\n')}',
    );
  });

  test('lengths outside the bank have no candidates', () {
    expect(SleuthGenerator.maxCandidates(3), 0);
    expect(SleuthGenerator.maxCandidates(9), 0);
  });
}
