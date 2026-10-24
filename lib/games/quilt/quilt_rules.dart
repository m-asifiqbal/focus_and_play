// Quilt rules: what a drawn patch "fits", the solved check and hints for the UI.
//
// Why separate from the generator: the UI calls these on every drag, so they are small
// and never search. `fits` is the same test the solver uses for its candidates, so a
// puzzle proven unique by the solver has exactly one way to satisfy `isSolved`.

import 'package:focus_and_play_mindgame/games/quilt/quilt_puzzle.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt_solver.dart';

/// Why a drawn patch is not right (what the UI explains in words).
enum QuiltFaultKind {
  /// The patch holds no clue.
  noClue,

  /// The patch holds two or more clues.
  manyClues,

  /// The clue's area differs from the patch's.
  wrongArea,

  /// The clue's shape (square / tall / wide) differs from the patch's.
  wrongShape,
}

/// The first reason a patch does not fit, with the numbers the message needs.
class QuiltFault {
  const QuiltFault(
    this.kind, {
    this.clues = 0,
    this.needArea,
    this.haveArea,
    this.needShape,
    this.haveShape,
  });
  final QuiltFaultKind kind;

  /// How many clues the patch holds (for [QuiltFaultKind.manyClues]).
  final int clues;
  final int? needArea, haveArea;
  final QuiltShape? needShape, haveShape;
}

/// The next teaching hint: which clue, where its patch goes, and how many
/// placements the clue had left before this one was chosen.
class QuiltHintPlan {
  const QuiltHintPlan({
    required this.clue,
    required this.rect,
    required this.options,
  });
  final int clue;
  final QuiltRect rect;

  /// Placements of that clue that don't overlap correctly placed patches (1 means
  /// the clue is forced).
  final int options;
}

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

  /// Why [r] does not fit, or null when it does ([fits] is exactly `fault == null`
  /// for rectangles inside the grid). A patch outside the grid counts as clue-less.
  static QuiltFault? fault(QuiltPuzzle p, QuiltRect r) {
    if (!r.isInside(p.size)) return const QuiltFault(QuiltFaultKind.noClue);
    var inside = 0;
    QuiltClue? only;
    for (final c in p.clues) {
      if (!r.contains(c.cell, p.size)) continue;
      inside++;
      only = c;
    }
    if (inside == 0) return const QuiltFault(QuiltFaultKind.noClue);
    if (inside > 1) return QuiltFault(QuiltFaultKind.manyClues, clues: inside);
    final c = only!;
    if (c.area != null && r.area != c.area) {
      return QuiltFault(
        QuiltFaultKind.wrongArea,
        clues: 1,
        needArea: c.area,
        haveArea: r.area,
      );
    }
    if (c.shape != null && r.shape != c.shape) {
      return QuiltFault(
        QuiltFaultKind.wrongShape,
        clues: 1,
        needShape: c.shape,
        haveShape: r.shape,
      );
    }
    return null;
  }

  /// Placed patches that are not part of the (unique) solution. A patch can fit its
  /// clue and still be wrong because it blocks another clue — only the solution
  /// tells, which is why this is a hint and not live feedback.
  static List<QuiltRect> wrongPatches(QuiltPuzzle p, List<QuiltRect> placed) {
    final sol = p.solution.toSet();
    return [
      for (final r in placed)
        if (!sol.contains(r)) r,
    ];
  }

  /// Hint: a solution patch that is not placed exactly yet. Prefers the clue with the
  /// fewest possible placements left (rectangles that fit it and don't overlap the
  /// correctly placed patches) — the most "obvious" next step — then clue order.
  /// Null when every solution patch is already placed (which includes solved).
  static QuiltRect? hint(QuiltPuzzle p, List<QuiltRect> placed) =>
      hintPlan(p, placed)?.rect;

  /// [hint] with the clue and the number of placements it had left, so the UI can
  /// explain the step ("only one place it can go").
  static QuiltHintPlan? hintPlan(QuiltPuzzle p, List<QuiltRect> placed) {
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
    return best == null
        ? null
        : QuiltHintPlan(clue: best, rect: p.solution[best], options: bestCount);
  }
}
