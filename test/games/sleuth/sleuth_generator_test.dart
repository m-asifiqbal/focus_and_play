// Sleuth generator tests: valid puzzles for every length / list size / tries the app can
// ask for, solvable by the hint strategy, non-trivial, deterministic, JSON-stable and fast.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

/// List sizes worth testing per word length (the bank offers fewer long words).
const _candidatesFor = {
  4: [6, 10, 16],
  5: [6, 10, 16],
  6: [6, 10, 16],
  7: [6, 8, 12],
  8: [6, 8, 10],
};
const _triesList = [4, 5, 6];
const _seeds = 12;

/// Checks everything a puzzle promises, with [why] naming the case.
void _expectValid(SleuthPuzzle p, SleuthParams params, String why) {
  expect(p.length, params.length, reason: why);
  expect(p.tries, params.tries, reason: why);
  expect(p.assist, params.assist, reason: why);
  expect(kWordThemes.containsKey(p.theme), isTrue, reason: '$why: theme');
  final bank = kWordThemes[p.theme]!;
  final available = bank.where((w) => w.length == p.length).toSet().length;
  final want = params.candidates < kSleuthMinCandidates
      ? kSleuthMinCandidates
      : params.candidates;
  expect(p.words.length, want < available ? want : available, reason: why);
  expect(p.words.length, greaterThanOrEqualTo(kSleuthMinCandidates));
  expect(p.words.toSet().length, p.words.length, reason: '$why: duplicates');
  for (var i = 0; i < p.words.length; i++) {
    final w = p.words[i];
    expect(w.length, p.length, reason: '$why: $w');
    expect(RegExp(r'^[A-Z]+$').hasMatch(w), isTrue, reason: '$why: $w');
    expect(bank, contains(w), reason: '$why: $w not in theme ${p.theme}');
    if (i > 0) {
      expect(
        w.compareTo(p.words[i - 1]),
        greaterThan(0),
        reason: '$why: order',
      );
    }
  }
  expect(p.secret, inInclusiveRange(0, p.words.length - 1), reason: why);
  // The hint strategy finds the secret within the tries.
  final run = SleuthRules.greedyRun(p);
  expect(SleuthRules.isSolved(p, run), isTrue, reason: '$why: not solvable');
  expect(run.length, lessThanOrEqualTo(p.tries), reason: why);
  expect(run.last.word, p.secret, reason: why);
}

void main() {
  test('every length × list size × tries × seed gives a valid puzzle', () {
    var count = 0;
    for (final e in _candidatesFor.entries) {
      for (final candidates in e.value) {
        for (final tries in _triesList) {
          final params = SleuthParams(
            length: e.key,
            candidates: candidates,
            tries: tries,
            assist: tries.isEven,
          );
          for (var seed = 0; seed < _seeds; seed++) {
            final why = '$params seed $seed';
            _expectValid(SleuthGenerator.generate(params, seed), params, why);
            count++;
          }
        }
      }
    }
    expect(count, 5 * 3 * 3 * _seeds);
  });

  test('the opening guess never hands over the answer', () {
    var checked = 0;
    for (final e in _candidatesFor.entries) {
      for (final candidates in e.value) {
        for (final tries in _triesList) {
          final params = SleuthParams(
            length: e.key,
            candidates: candidates,
            tries: tries,
          );
          for (var seed = 0; seed < _seeds; seed++) {
            final p = SleuthGenerator.generate(params, seed);
            // The secret is never the best opening guess itself, so at least one
            // round of deduction is always needed.
            expect(
              SleuthRules.bestGuess(p, const []),
              isNot(p.secret),
              reason: '$params seed $seed',
            );
            expect(SleuthRules.greedyRun(p).length, greaterThanOrEqualTo(2));
            checked++;
          }
        }
      }
    }
    expect(checked, 5 * 3 * 3 * _seeds);
  });

  test('short words / long lists: the opener leaves the secret ambiguous', () {
    // Where feedback is not overwhelmingly informative (4-letter lists, long 5-letter
    // lists) the first tier always succeeds: even the best opener cannot single out the
    // secret, so a perfect player still has to deduce after the first guess.
    var checked = 0;
    for (final (length, candidates) in [
      (4, 6),
      (4, 10),
      (4, 16),
      (5, 10),
      (5, 16),
    ]) {
      for (final tries in _triesList) {
        final params = SleuthParams(
          length: length,
          candidates: candidates,
          tries: tries,
        );
        for (var seed = 0; seed < _seeds; seed++) {
          final p = SleuthGenerator.generate(params, seed);
          final first = SleuthRules.bestGuess(p, const []);
          final left = SleuthRules.remaining(p, [SleuthRules.guess(p, first)]);
          expect(
            left.length,
            greaterThanOrEqualTo(2),
            reason: '$params seed $seed: the opener singles out the secret',
          );
          checked++;
        }
      }
    }
    expect(checked, 5 * 3 * _seeds);
  });

  test('every theme gets used and the secret is not always the same index', () {
    final themes = <String>{};
    final secrets = <int>{};
    for (var seed = 0; seed < 80; seed++) {
      final p = SleuthGenerator.generate(
        const SleuthParams(length: 5, candidates: 8, tries: 5),
        seed,
      );
      themes.add(p.theme);
      secrets.add(p.secret);
    }
    expect(themes.length, greaterThanOrEqualTo(6));
    expect(secrets.length, greaterThanOrEqualTo(5));
  });

  test('same seed gives identical JSON; different seeds differ', () {
    for (final length in [4, 5, 6, 7, 8]) {
      final params = SleuthParams(length: length, candidates: 8, tries: 5);
      final a = jsonEncode(SleuthGenerator.generate(params, 42).toJson());
      final b = jsonEncode(SleuthGenerator.generate(params, 42).toJson());
      expect(a, b, reason: 'length $length');
      final distinct = {
        for (var seed = 0; seed < 10; seed++)
          jsonEncode(SleuthGenerator.generate(params, seed).toJson()),
      };
      expect(
        distinct.length,
        greaterThanOrEqualTo(9),
        reason: 'length $length',
      );
      expect(
        a,
        isNot(jsonEncode(SleuthGenerator.generate(params, 43).toJson())),
      );
    }
  });

  test('JSON round trip keeps everything', () {
    for (final length in [4, 5, 6, 7, 8]) {
      final p = SleuthGenerator.generate(
        SleuthParams(length: length, candidates: 9, tries: 5, assist: false),
        7,
      );
      final text = jsonEncode(p.toJson());
      final q = SleuthPuzzle.fromJson(jsonDecode(text) as Map<String, Object?>);
      expect(jsonEncode(q.toJson()), text);
      expect(q.words, p.words);
      expect(q.secret, p.secret);
      expect(q.theme, p.theme);
      expect(q.assist, isFalse);
      expect(q.answer, p.answer);
    }
  });

  test('asking for more words than any theme has uses the largest theme', () {
    for (final length in [4, 5, 6, 7, 8]) {
      final most = SleuthGenerator.maxCandidates(length);
      final p = SleuthGenerator.generate(
        SleuthParams(length: length, candidates: 500, tries: 6),
        3,
      );
      expect(p.words.length, most, reason: 'length $length');
      // That theme really holds that many words of this length.
      final inTheme = kWordThemes[p.theme]!.where((w) => w.length == length);
      expect(inTheme.length, most);
    }
  });

  test('a list size below the minimum is raised to it', () {
    final p = SleuthGenerator.generate(
      const SleuthParams(length: 5, candidates: 2, tries: 6),
      1,
    );
    expect(p.words.length, kSleuthMinCandidates);
  });

  test(
    'a param set that rules out deduction still gives a solvable puzzle',
    () {
      // One try among 16 words: the only solvable secret is the opening guess itself, so
      // the generator falls back to it once the "not trivial" attempts are used up.
      const params = SleuthParams(length: 4, candidates: 16, tries: 1);
      final p = SleuthGenerator.generate(params, 0);
      expect(p.words.length, 16);
      expect(p.secret, SleuthRules.bestGuess(p, const []));
      expect(SleuthRules.greedyRun(p).length, 1);
    },
  );

  test('bad params are rejected', () {
    expect(
      () => SleuthGenerator.generate(
        const SleuthParams(length: 3, candidates: 8, tries: 5),
        0,
      ),
      throwsArgumentError,
    );
    expect(
      () => SleuthGenerator.generate(
        const SleuthParams(length: 9, candidates: 8, tries: 5),
        0,
      ),
      throwsArgumentError,
    );
    expect(
      () => SleuthGenerator.generate(
        const SleuthParams(length: 5, candidates: 8, tries: 0),
        0,
      ),
      throwsArgumentError,
    );
  });

  test('generation is fast for every length 4..8 × list size × tries', () {
    final timings = <String, String>{};
    var overall = 0.0;
    for (final length in [4, 5, 6, 7, 8]) {
      for (final candidates in [6, 10, 16]) {
        for (final tries in [4, 5, 6]) {
          final params = SleuthParams(
            length: length,
            candidates: candidates,
            tries: tries,
          );
          SleuthGenerator.generate(params, 1000); // JIT warm-up
          final sw = Stopwatch();
          var worst = 0;
          const runs = 20;
          for (var seed = 0; seed < runs; seed++) {
            final t0 = sw.elapsedMicroseconds;
            sw.start();
            SleuthGenerator.generate(params, seed);
            sw.stop();
            final us = sw.elapsedMicroseconds - t0;
            if (us > worst) worst = us;
          }
          final avgMs = sw.elapsedMicroseconds / runs / 1000;
          if (avgMs > overall) overall = avgMs;
          timings['$length/$candidates/$tries'] =
              '${avgMs.toStringAsFixed(2)}/${(worst / 1000).toStringAsFixed(1)}';
          expect(avgMs, lessThan(150), reason: '$params');
        }
      }
    }
    // ignore: avoid_print
    print('Sleuth generation (length/candidates/tries: avg/max ms): $timings');
    // ignore: avoid_print
    print('Sleuth slowest average: ${overall.toStringAsFixed(2)} ms');
  });

  test('level-tuning table: guesses needed by the hint and by a sensible player', () {
    // "hint" = the engine's strategy; "player" = someone who always picks a random word
    // still consistent with the feedback (no lookahead). Printed so levels can pick a
    // fair `tries`; asserted only loosely.
    final table = <String>[];
    for (final length in [4, 5, 6, 7, 8]) {
      for (final candidates in _candidatesFor[length]!) {
        final params = SleuthParams(
          length: length,
          candidates: candidates,
          tries: 6,
        );
        var hintTotal = 0, hintMax = 0, playerTotal = 0, playerMax = 0;
        final lost = {2: 0, 3: 0, 4: 0}; // games needing more than this many
        var ambiguous = 0, games = 0;
        const seeds = 40;
        for (var seed = 0; seed < seeds; seed++) {
          final p = SleuthGenerator.generate(params, seed);
          final hint = SleuthRules.greedyRun(p, maxGuesses: 99).length;
          hintTotal += hint;
          if (hint > hintMax) hintMax = hint;
          final first = SleuthRules.bestGuess(p, const []);
          if (SleuthRules.remaining(p, [SleuthRules.guess(p, first)]).length >=
              2) {
            ambiguous++;
          }
          final rng = Random(seed);
          for (var k = 0; k < 10; k++) {
            final history = <SleuthGuess>[];
            while (!SleuthRules.isSolved(p, history)) {
              final left = SleuthRules.remaining(p, history);
              history.add(SleuthRules.guess(p, left[rng.nextInt(left.length)]));
            }
            playerTotal += history.length;
            for (final t in lost.keys) {
              if (history.length > t) lost[t] = lost[t]! + 1;
            }
            if (history.length > playerMax) playerMax = history.length;
            games++;
          }
        }
        expect(hintMax, lessThanOrEqualTo(6));
        table.add(
          'len $length x $candidates words: hint avg '
          '${(hintTotal / seeds).toStringAsFixed(2)} max $hintMax; '
          'player avg ${(playerTotal / games).toStringAsFixed(2)} max $playerMax, '
          'loses with 2/3/4 tries: ${lost.values.map((x) => '${(100 * x / games).round()}%').join(' / ')}; '
          'opener leaves it ambiguous ${(100 * ambiguous / seeds).round()}%',
        );
      }
    }
    // ignore: avoid_print
    print('Sleuth tuning (tries 6, 40 seeds):\n${table.join('\n')}');
  });

  test('tighter tries (1..3) still give solvable puzzles', () {
    for (final tries in [1, 2, 3]) {
      for (final e in _candidatesFor.entries) {
        for (final candidates in e.value) {
          final params = SleuthParams(
            length: e.key,
            candidates: candidates,
            tries: tries,
          );
          for (var seed = 0; seed < 6; seed++) {
            _expectValid(
              SleuthGenerator.generate(params, seed),
              params,
              '$params seed $seed',
            );
          }
        }
      }
    }
  });
}
