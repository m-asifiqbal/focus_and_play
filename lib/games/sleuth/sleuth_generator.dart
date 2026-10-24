// Sleuth generator: a themed list of same-length words from the Twist word bank, a secret
// among them, and a proof (by simulation) that the puzzle can be solved within its tries.
//
// Why this shape: any list of words is a valid Sleuth board, so the work is quality, not
// existence. Two checks decide it. (1) Solvable: the hint strategy (`SleuthRules.bestGuess`
// again and again) must find the secret within `tries` guesses — the very code the player's
// hint button runs, so "the app can always show a way" is a fact, not a hope. (2) Not
// trivial: the best opening guess should NOT already single out the secret, otherwise a
// couple of clicks finish the board. That is easy to meet for short words and long lists,
// but long words are so informative (7-8 letters, a handful of candidates) that the best
// opener nearly always separates every word; so the check relaxes in tiers (see
// [SleuthGenerator.generate]) and, once relaxed, prefers the secret that the most
// first guesses leave ambiguous. A rejected list or secret is replaced by the next draw from
// the same seeded `Random`; every limit is a count and nothing depends on hash order, so a
// seed gives the same puzzle on every device.

import 'dart:math';

import 'package:focus_and_play_mindgame/games/sleuth/sleuth_puzzle.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth_rules.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

/// Builds Sleuth puzzles. Pure Dart, safe to call inside `Isolate.run`.
class SleuthGenerator {
  SleuthGenerator._();

  /// Lists tried (each a fresh theme + word draw) before giving up. Tests show a puzzle
  /// is normally found within a few; the bound only stops a hopeless param set from
  /// looping.
  static const int maxAttempts = 200;

  /// Attempts (tier 1) that insist the best opening guess leaves the secret ambiguous.
  static const int strictAttempts = 60;

  /// Attempts (tiers 1 and 2) that keep the secret from being the opening guess itself.
  /// Tier 3, after them, accepts any secret the hint strategy solves within the tries
  /// (e.g. when `tries` is 1, only the opener qualifies).
  static const int relaxedAttempts = 150;

  /// The most words of exactly [length] letters that any single theme offers — the real
  /// ceiling for `SleuthParams.candidates` at that length. 0 when no word has that length.
  static int maxCandidates(int length) {
    var most = 0;
    for (final pool in _pools(length)) {
      if (pool.words.length > most) most = pool.words.length;
    }
    return most;
  }

  /// Generates a puzzle for [p] and [seed].
  ///
  /// The list holds `p.candidates` words (at least [kSleuthMinCandidates]) from one
  /// theme; when no theme has that many of [SleuthParams.length] letters, the list is
  /// the largest theme's whole set of such words. Every puzzle is solvable by the hint
  /// strategy within `p.tries`. The secret is chosen by tier:
  ///  1. (first [strictAttempts] lists) a random secret whose feedback from the best
  ///     opening guess still leaves at least two candidates;
  ///  2. (up to [relaxedAttempts]) the solvable secret, other than the opener, that the
  ///     most first guesses leave ambiguous;
  ///  3. (after that) the same, opener allowed.
  ///
  /// Throws [ArgumentError] for a length outside the word bank's range or tries below 1,
  /// and [StateError] if no theme has even [kSleuthMinCandidates] words of that length
  /// or no solvable list is found within [maxAttempts].
  static SleuthPuzzle generate(SleuthParams p, int seed) {
    if (p.length < kTwistMinWordLength || p.length > kTwistMaxWordLength) {
      throw ArgumentError.value(
        p.length,
        'length',
        'must be $kTwistMinWordLength..$kTwistMaxWordLength',
      );
    }
    if (p.tries < 1) {
      throw ArgumentError.value(p.tries, 'tries', 'must be at least 1');
    }
    final pools = _pools(p.length);
    var most = 0;
    for (final pool in pools) {
      if (pool.words.length > most) most = pool.words.length;
    }
    if (most < kSleuthMinCandidates) {
      throw StateError(
        'Sleuth: no theme has $kSleuthMinCandidates words of ${p.length} letters',
      );
    }
    final wanted = p.candidates < kSleuthMinCandidates
        ? kSleuthMinCandidates
        : p.candidates;
    final count = wanted < most ? wanted : most;
    // Themes that can supply the whole list; the biggest theme always can.
    final eligible = [
      for (final pool in pools)
        if (pool.words.length >= count) pool,
    ];

    final rng = Random(seed);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final pool = eligible[rng.nextInt(eligible.length)];
      final words = _sample(pool.words, count, rng);
      final puzzle = _withSecret(p, pool.theme, words, rng, attempt);
      if (puzzle != null) return puzzle;
    }
    throw StateError('Sleuth: no solvable list for $p with seed $seed');
  }

  /// A puzzle on [words] whose secret passes the checks of this [attempt]'s tier, or
  /// null when none of the words does. Secrets are looked at in a random order so the
  /// answer is not biased by the alphabetical list.
  static SleuthPuzzle? _withSecret(
    SleuthParams p,
    String theme,
    List<String> words,
    Random rng,
    int attempt,
  ) {
    final n = words.length;
    SleuthPuzzle withSecret(int s) => SleuthPuzzle(
      theme: theme,
      length: p.length,
      words: words,
      secret: s,
      tries: p.tries,
      assist: p.assist,
    );
    // The opening hint does not depend on the secret, so compute it once per list.
    final opener = SleuthRules.bestGuess(withSecret(0), const []);
    final strict = attempt < strictAttempts;
    final order = _shuffled(n, rng);

    // Feedback of every guess against every possible answer, computed once.
    final grid = [
      for (final g in words) [for (final a in words) SleuthRules.pattern(g, a)],
    ];

    if (strict) {
      for (final s in order) {
        if (_sharing(grid[opener], s) < 2) continue;
        final puzzle = withSecret(s);
        if (_solvable(puzzle)) return puzzle;
      }
      return null;
    }

    // Relaxed: the solvable secret that the most first guesses leave ambiguous (ties go
    // to the earlier one in the random order, so it stays seed-driven).
    SleuthPuzzle? best;
    var bestHard = -1;
    for (final s in order) {
      if (s == opener && attempt < relaxedAttempts) continue;
      final hard = _ambiguousGuesses(grid, s);
      if (hard <= bestHard) continue;
      final puzzle = withSecret(s);
      if (!_solvable(puzzle)) continue;
      best = puzzle;
      bestHard = hard;
    }
    return best;
  }

  /// Whether the hint strategy finds the secret within the puzzle's tries.
  static bool _solvable(SleuthPuzzle p) =>
      SleuthRules.isSolved(p, SleuthRules.greedyRun(p));

  /// How many entries of [row] (one guess's feedback against every answer) equal the
  /// one for answer [s], counting [s] itself.
  static int _sharing(List<int> row, int s) {
    var same = 0;
    for (final x in row) {
      if (x == row[s]) same++;
    }
    return same;
  }

  /// Number of guesses (other than [s] itself) whose feedback leaves answer [s] tied
  /// with at least one other word — how hard the secret is to pin down from one guess.
  static int _ambiguousGuesses(List<List<int>> grid, int s) {
    var count = 0;
    for (var g = 0; g < grid.length; g++) {
      if (g != s && _sharing(grid[g], s) >= 2) count++;
    }
    return count;
  }

  /// [count] distinct words of [pool] drawn with a partial Fisher–Yates shuffle, sorted
  /// alphabetically.
  static List<String> _sample(List<String> pool, int count, Random rng) {
    final idx = List<int>.generate(pool.length, (i) => i);
    for (var i = 0; i < count; i++) {
      final j = i + rng.nextInt(idx.length - i);
      final t = idx[i];
      idx[i] = idx[j];
      idx[j] = t;
    }
    final words = [for (var i = 0; i < count; i++) pool[idx[i]]]..sort();
    return List<String>.unmodifiable(words);
  }

  /// 0..n-1 in random order.
  static List<int> _shuffled(int n, Random rng) {
    final order = List<int>.generate(n, (i) => i);
    for (var i = n - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    return order;
  }

  /// Each theme's words of exactly [length] letters, in bank order (a const map keeps
  /// source order, so every draw from these lists is stable). Themes with none are left
  /// out; a word repeated inside a theme counts once.
  static List<_Pool> _pools(int length) {
    final out = <_Pool>[];
    for (final e in kWordThemes.entries) {
      final seen = <String>{}; // membership only — never iterated
      final words = [
        for (final w in e.value)
          if (w.length == length && seen.add(w)) w,
      ];
      if (words.isNotEmpty) out.add(_Pool(e.key, words));
    }
    return out;
  }
}

/// One theme's words of a single length.
class _Pool {
  const _Pool(this.theme, this.words);

  final String theme;
  final List<String> words;
}
