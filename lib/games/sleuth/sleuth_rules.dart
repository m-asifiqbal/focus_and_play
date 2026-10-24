// Sleuth rules: Wordle-style scoring, "which words are still possible", the solved check
// and the best-next-guess hint.
//
// Why separate from the generator: the UI calls these after every guess and the generator
// uses the very same code to prove a puzzle solvable, so what the player sees and what
// was verified can never drift apart. Scoring works on an int "pattern" (base 3, letter 0
// is the least significant digit) because the hint compares thousands of feedbacks and
// ints compare and sort without allocating.

import 'package:focus_and_play_mindgame/games/sleuth/sleuth_puzzle.dart';

/// Feedback for one letter of a guess. The order matters: the index of a mark is its
/// digit in a pattern (see [SleuthRules.pattern]) and its value in saved games.
enum SleuthMark {
  /// The letter is not in the answer (or all its copies are already accounted for).
  absent,

  /// The letter is in the answer, but at another position.
  present,

  /// Right letter, right place.
  correct,
}

/// One guess and its feedback.
class SleuthGuess {
  /// Creates a guess of `puzzle.words[word]` with its per-letter [marks].
  const SleuthGuess(this.word, this.marks);

  /// Rebuilds a guess from [toJson] output.
  factory SleuthGuess.fromJson(Map<String, Object?> j) => SleuthGuess(
    (j['word'] as num).toInt(),
    List<SleuthMark>.unmodifiable([
      for (final m in j['marks'] as List) SleuthMark.values[(m as num).toInt()],
    ]),
  );

  /// Index into `puzzle.words`.
  final int word;

  /// One mark per letter, left to right.
  final List<SleuthMark> marks;

  /// Whether every letter is [SleuthMark.correct] (the guess was the secret).
  bool get isCorrect => marks.every((m) => m == SleuthMark.correct);

  /// Plain JSON (marks as their enum indices).
  Map<String, Object?> toJson() => {
    'word': word,
    'marks': [for (final m in marks) m.index],
  };

  @override
  bool operator ==(Object other) {
    if (other is! SleuthGuess ||
        other.word != word ||
        other.marks.length != marks.length) {
      return false;
    }
    for (var i = 0; i < marks.length; i++) {
      if (other.marks[i] != marks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(word, Object.hashAll(marks));

  @override
  String toString() => 'SleuthGuess($word, ${marks.map((m) => m.name[0])})';
}

/// Pure rule checks for Sleuth.
class SleuthRules {
  SleuthRules._();

  /// Longest word [pattern] and [score] accept (the used-letters mask is an int).
  static const int maxLength = 20;

  /// Standard Wordle scoring of [guess] against [answer], duplicates included: exact
  /// matches are marked first, then each remaining guess letter (left to right) is
  /// [SleuthMark.present] only while an unclaimed copy of it is left in the answer.
  /// Throws [ArgumentError] when the lengths differ or are not 1..[maxLength].
  static List<SleuthMark> score(String guess, String answer) =>
      decode(pattern(guess, answer), guess.length);

  /// [score] as one int: digit `i` (base 3, least significant first) is the index of
  /// the mark for letter `i`. Two feedbacks are equal exactly when their patterns are.
  static int pattern(String guess, String answer) {
    final n = guess.length;
    if (n < 1 || n > maxLength || answer.length != n) {
      throw ArgumentError(
        'guess "$guess" and answer "$answer" must have the same length '
        '1..$maxLength',
      );
    }
    // Bit j set = answer letter j is spoken for (exact match, or used up by a present).
    var claimed = 0;
    for (var i = 0; i < n; i++) {
      if (guess.codeUnitAt(i) == answer.codeUnitAt(i)) claimed |= 1 << i;
    }
    var code = 0, weight = 1;
    for (var i = 0; i < n; i++) {
      final g = guess.codeUnitAt(i);
      var mark = 0;
      if (g == answer.codeUnitAt(i)) {
        mark = 2;
      } else {
        for (var j = 0; j < n; j++) {
          if (((claimed >> j) & 1) == 0 && answer.codeUnitAt(j) == g) {
            claimed |= 1 << j;
            mark = 1;
            break;
          }
        }
      }
      code += mark * weight;
      weight *= 3;
    }
    return code;
  }

  /// The marks a [pattern] stands for ([length] letters).
  static List<SleuthMark> decode(int pattern, int length) {
    var rest = pattern;
    final out = <SleuthMark>[];
    for (var i = 0; i < length; i++) {
      out.add(SleuthMark.values[rest % 3]);
      rest ~/= 3;
    }
    return List<SleuthMark>.unmodifiable(out);
  }

  /// The pattern of [marks]; the inverse of [decode].
  static int encode(List<SleuthMark> marks) {
    var code = 0, weight = 1;
    for (final m in marks) {
      code += m.index * weight;
      weight *= 3;
    }
    return code;
  }

  /// Guesses `p.words[wordIndex]`: its feedback against the secret.
  static SleuthGuess guess(SleuthPuzzle p, int wordIndex) =>
      SleuthGuess(wordIndex, score(p.words[wordIndex], p.answer));

  /// Whether [candidate], were it the answer, would give exactly [marks] for [guess].
  /// False (never an error) when the lengths disagree.
  static bool matches(String candidate, String guess, List<SleuthMark> marks) {
    if (candidate.length != guess.length || marks.length != guess.length) {
      return false;
    }
    return pattern(guess, candidate) == encode(marks);
  }

  /// Ascending indices of the words still consistent with ALL the feedback in
  /// [history] — the candidates the UI may leave uncrossed. Always contains the secret
  /// when [history] came from [guess]. A guessed word that is not the secret drops out
  /// itself (it would have scored all-correct against itself).
  static List<int> remaining(SleuthPuzzle p, List<SleuthGuess> history) {
    final patterns = [for (final g in history) encode(g.marks)];
    final out = <int>[];
    for (var i = 0; i < p.words.length; i++) {
      var ok = true;
      for (var h = 0; h < history.length && ok; h++) {
        final g = history[h];
        final word = p.words[g.word];
        ok =
            g.marks.length == word.length &&
            pattern(word, p.words[i]) == patterns[h];
      }
      if (ok) out.add(i);
    }
    return out;
  }

  /// Whether some guess in [history] is the secret.
  static bool isSolved(SleuthPuzzle p, List<SleuthGuess> history) {
    for (final g in history) {
      if (g.word == p.secret) return true;
    }
    return false;
  }

  /// Hint: the index of the word to try next. Among words not yet guessed it picks the
  /// one that minimises the worst-case number of candidates left after its feedback
  /// (computed over [remaining], so it never peeks at the secret); ties prefer a word
  /// that is itself still possible, then the lowest index. Deterministic. Returns -1
  /// when the puzzle is solved or every word has been guessed.
  static int bestGuess(SleuthPuzzle p, List<SleuthGuess> history) {
    if (isSolved(p, history)) return -1;
    final n = p.words.length;
    final guessed = List<bool>.filled(n, false);
    for (final g in history) {
      guessed[g.word] = true;
    }
    final left = remaining(p, history);
    final possible = List<bool>.filled(n, false);
    for (final i in left) {
      possible[i] = true;
    }
    final buckets = List<int>.filled(left.length, 0);
    var best = -1, bestWorst = 0;
    for (var g = 0; g < n; g++) {
      if (guessed[g]) continue;
      for (var k = 0; k < left.length; k++) {
        buckets[k] = pattern(p.words[g], p.words[left[k]]);
      }
      final worst = _largestGroup(buckets);
      final better =
          best < 0 ||
          worst < bestWorst ||
          (worst == bestWorst && possible[g] && !possible[best]);
      if (better) {
        best = g;
        bestWorst = worst;
      }
    }
    return best;
  }

  /// Plays the hint strategy ([bestGuess] again and again) against the secret, for at
  /// most [maxGuesses] guesses (default `p.tries`), stopping early once solved. The
  /// generator uses it to prove a puzzle can be solved within its tries; the result is
  /// also the "par" line for a finished game.
  static List<SleuthGuess> greedyRun(SleuthPuzzle p, {int? maxGuesses}) {
    final limit = maxGuesses ?? p.tries;
    final history = <SleuthGuess>[];
    while (history.length < limit && !isSolved(p, history)) {
      final next = bestGuess(p, history);
      if (next < 0) break;
      history.add(guess(p, next));
    }
    return history;
  }

  /// Size of the biggest group of equal values in [values] (sorts it in place).
  static int _largestGroup(List<int> values) {
    if (values.isEmpty) return 0;
    values.sort();
    var best = 1, run = 1;
    for (var i = 1; i < values.length; i++) {
      run = values[i] == values[i - 1] ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }
}
