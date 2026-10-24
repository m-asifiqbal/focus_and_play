// Twist rules: what the player may trace, when a tracing finds a word, and hints.
//
// Why static, state-free functions: the UI owns the play state (the traced cells, the
// found word indices, the letters revealed by hints) and asks these questions on every
// drag step, so they stay cheap and never mutate their inputs.

import 'package:focus_and_play_mindgame/games/common/grid.dart';
import 'package:focus_and_play_mindgame/games/twist/twist_puzzle.dart';

/// Move validation, word matching and hints for a [TwistPuzzle].
class TwistRules {
  TwistRules._();

  /// Whether [cell] may extend the traced path: empty → any cell not in [foundWordIdx]
  /// words; else an edge neighbour of the last cell, not already traced, not part of a
  /// found word.
  static bool canAppend(
    TwistPuzzle p,
    List<int> traced,
    Set<int> foundWordIdx,
    int cell,
  ) {
    if (cell < 0 || cell >= p.cellCount) return false;
    if (_inFoundWord(p, foundWordIdx, cell)) return false;
    if (traced.isEmpty) return true;
    return isOrthogonalNeighbour(traced.last, cell, p.cols) &&
        !traced.contains(cell);
  }

  /// Index of the unfound word whose cells equal [traced] exactly (same order), else
  /// null. Reading a word backwards is not a match: words read first letter first.
  static int? match(TwistPuzzle p, List<int> traced, Set<int> foundWordIdx) {
    for (var i = 0; i < p.words.length; i++) {
      if (foundWordIdx.contains(i)) continue;
      if (_sameCells(p.words[i].cells, traced)) return i;
    }
    return null;
  }

  /// Index of an unfound word whose letters equal the traced letters but whose cells
  /// differ ("right word, other tiles"), so the UI can say so kindly; else null.
  ///
  /// Generated boards give every word a single tracing, so with paths built through
  /// [canAppend] this only fires on hand-made or older boards; it costs nothing to keep
  /// the kind message working for those.
  static int? sameWordOtherCells(
    TwistPuzzle p,
    List<int> traced,
    Set<int> foundWordIdx,
  ) {
    if (traced.isEmpty) return null;
    final spelled = StringBuffer();
    for (final c in traced) {
      if (c < 0 || c >= p.cellCount) return null;
      spelled.write(p.letters[c]);
    }
    final text = spelled.toString();
    for (var i = 0; i < p.words.length; i++) {
      if (foundWordIdx.contains(i)) continue;
      final w = p.words[i];
      if (w.word == text && !_sameCells(w.cells, traced)) return i;
    }
    return null;
  }

  /// Solved when every word has been found.
  static bool isSolved(TwistPuzzle p, Set<int> foundWordIdx) {
    for (var i = 0; i < p.words.length; i++) {
      if (!foundWordIdx.contains(i)) return false;
    }
    return true;
  }

  /// The unfound word to reveal next and how many of its leading letters to show.
  ///
  /// [revealed] is the UI's record (word index → letters already shown). Words are taken
  /// shortest first (ties → lower index) and each call shows one more letter of the
  /// first unfound word that isn't fully shown yet, so repeated calls keep working on the
  /// same word until it is spelled out. When every unfound word is already fully shown,
  /// the shortest one is returned again with all its letters.
  ///
  /// Throws [StateError] when the puzzle is solved (the UI hides the hint button then).
  static TwistHint hint(
    TwistPuzzle p,
    Set<int> foundWordIdx,
    Map<int, int> revealed,
  ) {
    final order = [
      for (var i = 0; i < p.words.length; i++)
        if (!foundWordIdx.contains(i)) i,
    ];
    if (order.isEmpty) {
      throw StateError('Twist hint requested on a solved puzzle');
    }
    // Stable: ties keep the lower index (words are normally pre-sorted anyway).
    order.sort((a, b) {
      final byLen = p.words[a].length.compareTo(p.words[b].length);
      return byLen != 0 ? byLen : a.compareTo(b);
    });
    for (final i in order) {
      final shown = (revealed[i] ?? 0).clamp(0, p.words[i].length);
      if (shown < p.words[i].length) {
        return TwistHint(wordIndex: i, lettersShown: shown + 1);
      }
    }
    final first = order.first;
    return TwistHint(wordIndex: first, lettersShown: p.words[first].length);
  }

  static bool _inFoundWord(TwistPuzzle p, Set<int> foundWordIdx, int cell) {
    for (final i in foundWordIdx) {
      if (i >= 0 && i < p.words.length && p.words[i].cells.contains(cell)) {
        return true;
      }
    }
    return false;
  }

  static bool _sameCells(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
