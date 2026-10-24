// Quilt rules: what a drawn patch "fits", the solved check and hints for the UI.
//
// Why separate from the generator: the UI calls these on every drag, so they are small
// and never search. `fits` is the same test the solver uses for its candidates, so a
// puzzle proven unique by the solver has exactly one way to satisfy `isSolved`.

import 'package:focus_and_play_mindgame/games/quilt/quilt_puzzle.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt_solver.dart';

/// Pure rule checks for Quilt.
class QuiltRules {
  QuiltRules._();

  /// Index of the single clue inside [r], or null when it holds 0 or 2+ clues.
  static int? clueIn(QuiltPuzzle p, QuiltRect r) {
    int? found;
    for (var i = 0; i < p.clues.length; i++) {
      if (!r.contains(p.clues[i].cell, p.size)) continue;
      if (found != null) return null;
      found = i;
    }
    return found;
  }

  /// A drawn rectangle "fits" when it lies inside the grid, holds exactly one clue and
  /// matches that clue's area/shape. (The UI colours fitting patches; others show as a
  /// warning.)
  static bool fits(QuiltPuzzle p, QuiltRect r) {
    if (!r.isInside(p.size)) return false;
    final i = clueIn(p, r);
    return i != null && p.clues[i].matches(r);
  }

  /// Solved = the rectangles don't overlap, cover the whole grid, and every one fits.
  static bool isSolved(QuiltPuzzle p, List<QuiltRect> placed) {
    final n = p.size;
    final covered = List<bool>.filled(n * n, false);
    var count = 0;
    for (final r in placed) {
      if (!fits(p, r)) return false;
      for (final c in r.cells(n)) {
        if (covered[c]) return false;
        covered[c] = true;
        count++;
      }
    }
    return count == n * n;
  }

  /// Hint: a solution patch that is not placed exactly yet. Prefers the clue with the
  /// fewest possible placements left (rectangles that fit it and don't overlap the
  /// correctly placed patches) — the most "obvious" next step — then clue order.
  /// Null when every solution patch is already placed (which includes solved).
  static QuiltRect? hint(QuiltPuzzle p, List<QuiltRect> placed) {
    if (isSolved(p, placed)) return null;
    final done = placed.toSet();
    final correct = [
      for (final r in p.solution)
        if (done.contains(r)) r,
    ];
    int? best;
    var bestCount = 0;
    for (var i = 0; i < p.clues.length; i++) {
      if (done.contains(p.solution[i])) continue;
      final options = QuiltSolver.candidatesFor(
        p.size,
        p.clues,
        i,
      ).where((r) => !correct.any(r.overlaps)).length;
      if (best == null || options < bestCount) {
        best = i;
        bestCount = options;
      }
    }
    return best == null ? null : p.solution[best];
  }
}
