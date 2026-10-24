// Sleuth rules tests: Wordle scoring (duplicate letters!), matches/remaining consistency,
// the solved check and the minimax hint.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

const _a = SleuthMark.absent;
const _p = SleuthMark.present;
const _c = SleuthMark.correct;

/// An independent, count-based Wordle scorer to cross-check the engine's.
List<SleuthMark> _reference(String guess, String answer) {
  final marks = List<SleuthMark>.filled(guess.length, _a);
  final spare = <String, int>{};
  for (var i = 0; i < guess.length; i++) {
    if (guess[i] == answer[i]) {
      marks[i] = _c;
    } else {
      spare[answer[i]] = (spare[answer[i]] ?? 0) + 1;
    }
  }
  for (var i = 0; i < guess.length; i++) {
    if (marks[i] == _c) continue;
    final left = spare[guess[i]] ?? 0;
    if (left > 0) {
      marks[i] = _p;
      spare[guess[i]] = left - 1;
    }
  }
  return marks;
}

/// Every theme's same-length word groups (length ≥ 2 words), for all-pairs checks.
Iterable<(String, List<String>)> _groups() sync* {
  for (final e in kWordThemes.entries) {
    for (var len = kTwistMinWordLength; len <= kTwistMaxWordLength; len++) {
      final words = [
        for (final w in e.value)
          if (w.length == len) w,
      ];
      if (words.length >= 2) yield ('${e.key}/$len', words);
    }
  }
}

SleuthPuzzle _puzzle(List<String> words, int secret, {int tries = 6}) =>
    SleuthPuzzle(
      theme: 'Test',
      length: words.first.length,
      words: List.of(words)..sort(),
      secret: secret,
      tries: tries,
      assist: true,
    );

const _ocean5 = ['CORAL', 'SHARK', 'WHALE', 'BEACH', 'OCEAN', 'WATER', 'SQUID'];

void main() {
  group('score', () {
    test('exact word is all correct', () {
      expect(SleuthRules.score('CORAL', 'CORAL'), [_c, _c, _c, _c, _c]);
    });

    test('no shared letters is all absent', () {
      expect(SleuthRules.score('FISH', 'CRAB'), [_a, _a, _a, _a]);
    });

    test('LLAMA vs BALLS: two Ls and one A count, the second A does not', () {
      // Hand worked: no exact hits; L,L take BALLS' two Ls; the first A takes its A;
      // M is not in BALLS; the second A finds the only A already used.
      expect(SleuthRules.score('LLAMA', 'BALLS'), [_p, _p, _p, _a, _a]);
    });

    test('BALLS vs LLAMA is not the mirror image', () {
      // The first L takes LLAMA's first L, the second its second; A takes the first A.
      expect(SleuthRules.score('BALLS', 'LLAMA'), [_a, _p, _p, _p, _a]);
    });

    test('a second copy of a letter in the guess is absent', () {
      // SPEED vs ABIDE: only one E in the answer, so the first E is present, the
      // second absent.
      expect(SleuthRules.score('SPEED', 'ABIDE'), [_a, _a, _p, _a, _p]);
    });

    test('exact matches claim a letter before earlier misplaced copies', () {
      // SASSY vs LASSO: the answer's two Ss are both hit exactly, so the S at the
      // front finds nothing left and is absent (not present).
      expect(SleuthRules.score('SASSY', 'LASSO'), [_a, _c, _c, _c, _a]);
      // LEVEL vs ELDER: the E at index 3 is exact; the other E and the first L are
      // present; the last L has no copy left.
      expect(SleuthRules.score('LEVEL', 'ELDER'), [_p, _p, _a, _c, _a]);
    });

    test('exact hit plus misplaced copies', () {
      // LLAMA vs SMALL: A is exact; both Ls and the M are misplaced; the second A
      // has no copy left.
      expect(SleuthRules.score('LLAMA', 'SMALL'), [_p, _p, _c, _p, _a]);
    });

    test('anagram is all present', () {
      expect(SleuthRules.score('ALLOY', 'LOYAL'), [_p, _p, _p, _p, _p]);
    });

    test('lengths must agree', () {
      expect(() => SleuthRules.score('CORAL', 'SHARKS'), throwsArgumentError);
      expect(() => SleuthRules.score('', ''), throwsArgumentError);
    });

    test('agrees with an independent scorer on every pair of every group', () {
      var pairs = 0;
      for (final (name, words) in _groups()) {
        for (final g in words) {
          for (final a in words) {
            expect(
              SleuthRules.score(g, a),
              _reference(g, a),
              reason: '$name: $g vs $a',
            );
            pairs++;
          }
        }
      }
      expect(pairs, greaterThan(5000));
    });

    test('agrees on random letter soup with many repeats', () {
      final rng = Random(5);
      String soup(int n) => String.fromCharCodes([
        for (var i = 0; i < n; i++)
          65 + rng.nextInt(4), // only A..D: lots of repeats
      ]);
      for (var i = 0; i < 3000; i++) {
        final n = 4 + rng.nextInt(5);
        final g = soup(n), a = soup(n);
        expect(SleuthRules.score(g, a), _reference(g, a), reason: '$g vs $a');
      }
    });
  });

  group('pattern', () {
    test('encode and decode are inverse', () {
      for (final (name, words) in _groups()) {
        for (final a in words.take(4)) {
          for (final g in words.take(4)) {
            final marks = SleuthRules.score(g, a);
            final code = SleuthRules.pattern(g, a);
            expect(SleuthRules.encode(marks), code, reason: '$name $g/$a');
            expect(SleuthRules.decode(code, g.length), marks);
          }
        }
      }
    });

    test('the all-correct pattern is only reached by the word itself', () {
      final all = SleuthRules.encode(List.filled(5, _c));
      expect(SleuthRules.pattern('CORAL', 'CORAL'), all);
      expect(SleuthRules.pattern('CORAL', 'COLAR'), isNot(all));
      expect(SleuthRules.encode(const [_a, _p, _c]), 0 + 3 + 2 * 9);
    });
  });

  group('matches', () {
    test('agrees with score for all word pairs of a sample theme', () {
      final words = [
        for (final w in kWordThemes['Ocean']!)
          if (w.length == 5) w,
      ];
      expect(words.length, greaterThanOrEqualTo(10));
      for (final guess in words) {
        for (final answer in words) {
          final marks = SleuthRules.score(guess, answer);
          for (final candidate in words) {
            final expected =
                _reference(guess, candidate).join() == marks.join();
            expect(
              SleuthRules.matches(candidate, guess, marks),
              expected,
              reason: 'guess $guess, answer $answer, candidate $candidate',
            );
          }
          // The answer always matches its own feedback.
          expect(SleuthRules.matches(answer, guess, marks), isTrue);
        }
      }
    });

    test('mismatched lengths simply do not match', () {
      expect(
        SleuthRules.matches('SHARKS', 'SHARK', [_c, _c, _c, _c, _c]),
        false,
      );
      expect(SleuthRules.matches('SHARK', 'SHARK', [_c, _c, _c]), isFalse);
    });

    test('hand-worked: which answers fit one clue', () {
      // Guess LLAMA, feedback [P,P,P,A,A] -> BALLS fits; SMALL (A exact) does not.
      const marks = [_p, _p, _p, _a, _a];
      expect(SleuthRules.matches('BALLS', 'LLAMA', marks), isTrue);
      expect(SleuthRules.matches('SMALL', 'LLAMA', marks), isFalse);
      expect(SleuthRules.matches('LLAMA', 'LLAMA', marks), isFalse);
    });
  });

  group('remaining / isSolved', () {
    test('empty history keeps every word; ascending', () {
      final p = _puzzle(_ocean5, 2);
      expect(SleuthRules.remaining(p, const []), [
        for (var i = 0; i < p.words.length; i++) i,
      ]);
      expect(SleuthRules.isSolved(p, const []), isFalse);
    });

    test('shrinks monotonically and always keeps the secret', () {
      final rng = Random(11);
      var checked = 0;
      for (final (_, words) in _groups()) {
        if (words.length < 6) continue;
        final list = words.take(12).toList()..sort();
        final secret = rng.nextInt(list.length);
        final p = _puzzle(list, secret);
        final order = List<int>.generate(list.length, (i) => i)..shuffle(rng);
        final history = <SleuthGuess>[];
        var before = SleuthRules.remaining(p, history);
        for (final w in order) {
          history.add(SleuthRules.guess(p, w));
          final after = SleuthRules.remaining(p, history);
          expect(after.length, lessThanOrEqualTo(before.length));
          expect(before, containsAll(after), reason: 'only ever shrinks');
          expect(after, contains(secret));
          expect(after, orderedEquals([...after]..sort()));
          before = after;
          if (SleuthRules.isSolved(p, history)) break;
        }
        // Once the secret has been guessed it is the last word standing.
        expect(before, [secret]);
        checked++;
      }
      expect(checked, greaterThan(30));
    });

    test('a wrong guess removes itself', () {
      final p = _puzzle(_ocean5, 2);
      final wrong = p.secret == 0 ? 1 : 0;
      final left = SleuthRules.remaining(p, [SleuthRules.guess(p, wrong)]);
      expect(left, isNot(contains(wrong)));
      expect(left, contains(p.secret));
    });

    test('isSolved follows the secret, not the marks of other guesses', () {
      final p = _puzzle(_ocean5, 3);
      final other = p.secret == 0 ? 1 : 0;
      expect(SleuthRules.isSolved(p, [SleuthRules.guess(p, other)]), isFalse);
      final win = SleuthRules.guess(p, p.secret);
      expect(win.isCorrect, isTrue);
      expect(
        SleuthRules.isSolved(p, [SleuthRules.guess(p, other), win]),
        isTrue,
      );
    });
  });

  group('bestGuess', () {
    // Brute-force reference of the documented rule.
    int reference(SleuthPuzzle p, List<SleuthGuess> history) {
      final left = SleuthRules.remaining(p, history);
      final guessed = {for (final g in history) g.word};
      var best = -1, bestWorst = 1 << 30, bestPossible = false;
      for (var g = 0; g < p.words.length; g++) {
        if (guessed.contains(g)) continue;
        final sizes = <int, int>{};
        for (final a in left) {
          final code = SleuthRules.pattern(p.words[g], p.words[a]);
          sizes[code] = (sizes[code] ?? 0) + 1;
        }
        final worst = sizes.values.fold(0, max);
        final possible = left.contains(g);
        if (worst < bestWorst ||
            (worst == bestWorst && possible && !bestPossible)) {
          best = g;
          bestWorst = worst;
          bestPossible = possible;
        }
      }
      return best;
    }

    test('matches the documented minimax rule over whole games', () {
      var games = 0;
      for (final (name, words) in _groups()) {
        if (words.length < 6) continue;
        final list = words.take(10).toList()..sort();
        for (var secret = 0; secret < list.length; secret += 3) {
          final p = _puzzle(list, secret);
          final history = <SleuthGuess>[];
          while (!SleuthRules.isSolved(p, history)) {
            final want = reference(p, history);
            expect(
              SleuthRules.bestGuess(p, history),
              want,
              reason: '$name secret $secret after ${history.length} guesses',
            );
            history.add(SleuthRules.guess(p, want));
            expect(history.length, lessThanOrEqualTo(list.length));
          }
          games++;
        }
      }
      expect(games, greaterThan(40));
    });

    test('is deterministic and never repeats a guess', () {
      final p = _puzzle(_ocean5, 4);
      final a = SleuthRules.bestGuess(p, const []);
      expect(SleuthRules.bestGuess(p, const []), a);
      final history = [SleuthRules.guess(p, a)];
      final b = SleuthRules.bestGuess(p, history);
      expect(b, isNot(a));
      expect(SleuthRules.bestGuess(p, history), b);
      // Equal puzzles built twice agree too.
      expect(SleuthRules.bestGuess(_puzzle(_ocean5, 4), history), b);
    });

    test('does not depend on the secret, only on the feedback', () {
      // Two puzzles with the same list and one shared feedback line give the same hint.
      final p1 = _puzzle(_ocean5, 1), p2 = _puzzle(_ocean5, 5);
      expect(
        SleuthRules.bestGuess(p1, const []),
        SleuthRules.bestGuess(p2, const []),
      );
      final line = SleuthRules.guess(p1, 0);
      if (SleuthRules.remaining(p2, [line]).contains(p2.secret)) {
        expect(
          SleuthRules.bestGuess(p1, [line]),
          SleuthRules.bestGuess(p2, [line]),
        );
      }
    });

    test('with one candidate left it names that candidate', () {
      final p = _puzzle(_ocean5, 4);
      var history = <SleuthGuess>[];
      while (SleuthRules.remaining(p, history).length > 1) {
        history = [
          ...history,
          SleuthRules.guess(p, SleuthRules.bestGuess(p, history)),
        ];
      }
      final last = SleuthRules.remaining(p, history);
      expect(last, [p.secret]);
      if (!SleuthRules.isSolved(p, history)) {
        expect(SleuthRules.bestGuess(p, history), p.secret);
      }
    });

    test('prefers a possible word, then the lowest index, on ties', () {
      // All words share no letters with each other: every guess splits nothing, so the
      // worst case is the same for all; a still-possible word wins, lowest index first.
      final p = _puzzle(['ABCD', 'EFGH', 'IJKL', 'MNOP'], 2);
      expect(SleuthRules.bestGuess(p, const []), 0);
      final miss = SleuthRules.guess(p, 0); // all absent -> 0 drops out
      expect(SleuthRules.bestGuess(p, [miss]), 1);
    });

    test('returns -1 when solved or nothing is left to guess', () {
      final p = _puzzle(_ocean5, 2);
      expect(SleuthRules.bestGuess(p, [SleuthRules.guess(p, p.secret)]), -1);
      final all = [
        for (var i = 0; i < p.words.length; i++)
          if (i != p.secret) SleuthRules.guess(p, i),
      ];
      // Everything but the secret guessed: the secret is the only word left to try.
      expect(SleuthRules.bestGuess(p, all), p.secret);
      expect(
        SleuthRules.bestGuess(p, [...all, SleuthRules.guess(p, p.secret)]),
        -1,
      );
    });
  });

  group('guess / greedyRun / SleuthGuess', () {
    test('guess scores the word against the answer', () {
      final p = _puzzle(
        _ocean5,
        2,
      ); // sorted: BEACH CORAL OCEAN SHARK SQUID WATER WHALE
      expect(p.answer, 'OCEAN');
      final g = SleuthRules.guess(p, 1);
      expect(g.word, 1);
      expect(g.marks, SleuthRules.score('CORAL', 'OCEAN'));
    });

    test('greedyRun stops when solved and respects the limit', () {
      final p = _puzzle(_ocean5, 2);
      final run = SleuthRules.greedyRun(p);
      expect(SleuthRules.isSolved(p, run), isTrue);
      expect(run.length, lessThanOrEqualTo(p.words.length));
      expect(run.last.word, p.secret);
      final short = SleuthRules.greedyRun(p, maxGuesses: 1);
      expect(short.length, 1);
      expect(SleuthRules.greedyRun(p, maxGuesses: 0), isEmpty);
    });

    test('guess JSON round trip and value equality', () {
      final p = _puzzle(_ocean5, 2);
      final g = SleuthRules.guess(p, 1);
      final back = SleuthGuess.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>,
      );
      expect(back, g);
      expect(back.hashCode, g.hashCode);
      expect(back, isNot(SleuthRules.guess(p, 3)));
      expect(g.isCorrect, isFalse);
    });
  });
}
