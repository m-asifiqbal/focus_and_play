// Twist board generator: one random Hamiltonian path, cut into word-length pieces and
// filled with words of a single theme.
//
// Why this shape: cutting a path that visits every cell once guarantees the words tile
// the board and each word's letters are edge-adjacent. The extra check — every word can
// be traced on exactly ONE cell sequence of the finished board — makes the intended
// partition the only reading, so the player is never told "wrong tiles" for a tracing
// that spells a listed word. Boards failing it get word swaps, then a fresh path/cut/
// theme; every choice comes from one seeded Random and every limit is a count, so the
// same params + seed give the same board on every device.

import 'dart:math';

import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/common/hamiltonian.dart';
import 'package:focus_and_play_mindgame/games/twist/twist_puzzle.dart';
import 'package:focus_and_play_mindgame/games/twist/word_bank.dart';

/// Builds Twist boards. Pure Dart, safe to call inside `Isolate.run`.
class TwistGenerator {
  TwistGenerator._();

  /// Fresh path + cut + theme combinations tried before giving up. Tests show a board is
  /// normally found within a handful; the bound only keeps a bad param set from looping.
  static const int maxAttempts = 400;

  /// Rounds of "swap every ambiguous word for another word of the same length" tried on
  /// one path + cut before starting over. Swapping is far cheaper than a new path.
  static const int repairRounds = 24;

  /// Generates the board for [p] and [seed].
  ///
  /// Throws [ArgumentError] when [p] can't be tiled (see [TwistParams]) and
  /// [StateError] if no board is found within [maxAttempts] (never seen in tests).
  static TwistPuzzle generate(TwistParams p, int seed) {
    final feasible = _validate(p);
    final n = p.rows * p.cols;
    final rng = Random(seed);
    final adj = [for (var c = 0; c < n; c++) neighboursOf(c, p.rows, p.cols)];
    // A const map keeps source order, so this list (and every draw from it) is stable.
    final themes = kWordThemes.keys.toList(growable: false);
    final pools = {
      for (final t in themes)
        t: _poolByLength(kWordThemes[t]!, p.minLen, p.maxLen),
    };

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final theme = themes[rng.nextInt(themes.length)];
      final pool = pools[theme]!;
      final path = randomHamiltonianPath(p.rows, p.cols, rng);
      final lengths = _cutLengths(n, p.minLen, p.maxLen, feasible, rng);
      final pieces = <List<int>>[];
      var at = 0;
      for (final len in lengths) {
        final piece = path.sublist(at, at + len);
        // The path's direction is arbitrary, so each word may read either way along it.
        pieces.add(rng.nextBool() ? piece : piece.reversed.toList());
        at += len;
      }
      final puzzle = _fill(p, theme, pieces, pool, adj, rng);
      if (puzzle != null) return puzzle;
    }
    throw StateError('Twist: no board for $p with seed $seed');
  }

  /// Throws [ArgumentError] for params no board can satisfy; returns the feasible-total
  /// table (see [_feasibleTotals]) the cutter needs.
  static List<bool> _validate(TwistParams p) {
    if (p.rows < 2 || p.cols < 2) {
      throw ArgumentError.value(p, 'p', 'rows and cols must be at least 2');
    }
    if (p.minLen < kTwistMinWordLength ||
        p.maxLen > kTwistMaxWordLength ||
        p.minLen > p.maxLen) {
      throw ArgumentError.value(
        p,
        'p',
        'word lengths must satisfy '
            '$kTwistMinWordLength <= minLen <= maxLen <= $kTwistMaxWordLength',
      );
    }
    final n = p.rows * p.cols;
    final feasible = _feasibleTotals(n, p.minLen, p.maxLen);
    if (!feasible[n]) {
      throw ArgumentError.value(
        p,
        'p',
        'rows*cols is not a sum of word lengths',
      );
    }
    return feasible;
  }

  /// `feasible[t]` = t can be written as a sum of lengths in minLen..maxLen.
  static List<bool> _feasibleTotals(int n, int minLen, int maxLen) {
    final f = List<bool>.filled(n + 1, false);
    f[0] = true;
    for (var t = 1; t <= n; t++) {
      for (var l = minLen; l <= maxLen && l <= t && !f[t]; l++) {
        f[t] = f[t - l];
      }
    }
    return f;
  }

  /// Random piece lengths summing to [n]; each pick leaves a still-feasible remainder,
  /// so no backtracking is needed.
  static List<int> _cutLengths(
    int n,
    int minLen,
    int maxLen,
    List<bool> feasible,
    Random rng,
  ) {
    final out = <int>[];
    var left = n;
    while (left > 0) {
      final options = [
        for (var l = minLen; l <= maxLen && l <= left; l++)
          if (feasible[left - l]) l,
      ];
      final l = options[rng.nextInt(options.length)];
      out.add(l);
      left -= l;
    }
    return out;
  }

  /// Theme words grouped by length (only lengths in range), in bank order.
  static Map<int, List<String>> _poolByLength(
    List<String> words,
    int minLen,
    int maxLen,
  ) => {
    for (var l = minLen; l <= maxLen; l++)
      l: [
        for (final w in words)
          if (w.length == l) w,
      ],
  };

  /// Puts words on [pieces] and swaps ambiguous ones until every word has exactly one
  /// tracing; null when the theme runs out of words or [repairRounds] is exhausted.
  static TwistPuzzle? _fill(
    TwistParams p,
    String theme,
    List<List<int>> pieces,
    Map<int, List<String>> pool,
    List<List<int>> adj,
    Random rng,
  ) {
    final used =
        <String>{}; // membership only — never iterated, so hash order is moot
    final words = <String>[];
    for (final piece in pieces) {
      final w = _pick(pool[piece.length]!, used, rng);
      if (w == null) return null;
      words.add(w);
      used.add(w);
    }
    final letters = List<int>.filled(p.rows * p.cols, 0);
    for (var round = 0; round < repairRounds; round++) {
      for (var i = 0; i < pieces.length; i++) {
        for (var k = 0; k < pieces[i].length; k++) {
          letters[pieces[i][k]] = words[i].codeUnitAt(k);
        }
      }
      var unique = true;
      for (var i = 0; i < words.length; i++) {
        if (_countTracings(letters, adj, words[i], 2) == 1) continue;
        unique = false;
        // Later words in this round are judged on the old letters; that's fine because
        // a board is only accepted after a full round with no swaps.
        final w = _pick(pool[words[i].length]!, used, rng);
        if (w == null) return null;
        used
          ..remove(words[i])
          ..add(w);
        words[i] = w;
      }
      if (unique) return _build(p, theme, pieces, words, letters);
    }
    return null;
  }

  /// A random word from [list] not in [used], or null when all are used.
  static String? _pick(List<String> list, Set<String> used, Random rng) {
    final free = [
      for (final w in list)
        if (!used.contains(w)) w,
    ];
    return free.isEmpty ? null : free[rng.nextInt(free.length)];
  }

  /// Number of cell sequences spelling [word] (edge steps, no cell reused), up to [limit].
  static int _countTracings(
    List<int> letters,
    List<List<int>> adj,
    String word,
    int limit,
  ) {
    final codes = word.codeUnits;
    final last = codes.length - 1;
    final inUse = List<bool>.filled(letters.length, false);
    var count = 0;

    // True once [limit] tracings are found, to stop the search early.
    bool walk(int cell, int k) {
      if (k == last) return ++count >= limit;
      inUse[cell] = true;
      for (final nb in adj[cell]) {
        if (!inUse[nb] && letters[nb] == codes[k + 1] && walk(nb, k + 1)) {
          inUse[cell] = false;
          return true;
        }
      }
      inUse[cell] = false;
      return false;
    }

    for (var c = 0; c < letters.length; c++) {
      if (letters[c] == codes[0] && walk(c, 0)) break;
    }
    return count;
  }

  static TwistPuzzle _build(
    TwistParams p,
    String theme,
    List<List<int>> pieces,
    List<String> words,
    List<int> letters,
  ) {
    final list = [
      for (var i = 0; i < pieces.length; i++)
        TwistWord(word: words[i], cells: List<int>.unmodifiable(pieces[i])),
    ];
    // Shortest first, then top-left first: the order the UI lists the words in.
    list.sort((a, b) {
      final byLen = a.length.compareTo(b.length);
      return byLen != 0 ? byLen : a.cells.first.compareTo(b.cells.first);
    });
    return TwistPuzzle(
      rows: p.rows,
      cols: p.cols,
      letters: List<String>.unmodifiable(letters.map(String.fromCharCode)),
      words: List<TwistWord>.unmodifiable(list),
      theme: theme,
    );
  }
}
