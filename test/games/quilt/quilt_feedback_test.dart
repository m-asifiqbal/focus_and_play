// Quilt's "why is this wrong" and teaching-hint rules: fault, wrongPatches, hintPlan.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';

void main() {
  // Same hand-made 4×4 puzzle as quilt_rules_test.dart:
  //   A A B B   A = 2×2 at (0,0), clue area 4 on cell 0
  //   A A B B   B = 2×2 at (0,2), clue "square" on cell 7
  //   C C C C   C = 4×1 wide at (2,0), clue area 4 + wide on cell 9
  //   D D D D   D = 4×1 wide at (3,0), clue area 4 on cell 15
  const a = QuiltRect(row: 0, col: 0, width: 2, height: 2);
  const b = QuiltRect(row: 0, col: 2, width: 2, height: 2);
  const c = QuiltRect(row: 2, col: 0, width: 4, height: 1);
  const d = QuiltRect(row: 3, col: 0, width: 4, height: 1);
  final puzzle = QuiltPuzzle(
    size: 4,
    clues: const [
      QuiltClue(cell: 0, area: 4),
      QuiltClue(cell: 7, shape: QuiltShape.square),
      QuiltClue(cell: 9, area: 4, shape: QuiltShape.wide),
      QuiltClue(cell: 15, area: 4),
    ],
    solution: const [a, b, c, d],
  );

  test('no clue, several clues, wrong size, wrong shape', () {
    // Row 1 (cells 4..7) holds the clue on cell 7 only; cells 4,5 hold none.
    final noClue = QuiltRules.fault(
      puzzle,
      const QuiltRect(row: 1, col: 0, width: 2, height: 1),
    );
    expect(noClue!.kind, QuiltFaultKind.noClue);

    // Rows 0–1 across all four columns hold the clues on cells 0 and 7.
    final many = QuiltRules.fault(
      puzzle,
      const QuiltRect(row: 0, col: 0, width: 4, height: 2),
    );
    expect(many!.kind, QuiltFaultKind.manyClues);
    expect(many.clues, 2);

    // Clue 0 wants area 4; a 1×2 has 2.
    final area = QuiltRules.fault(
      puzzle,
      const QuiltRect(row: 0, col: 0, width: 1, height: 2),
    );
    expect(area!.kind, QuiltFaultKind.wrongArea);
    expect([area.needArea, area.haveArea], [4, 2]);

    // Clue 9 wants area 4 AND wide: a 2×2 square has the right area, wrong shape.
    final shape = QuiltRules.fault(
      puzzle,
      const QuiltRect(row: 1, col: 0, width: 2, height: 2),
    );
    expect(
      shape,
      isNotNull,
      reason: 'holds clue 9 only (cell 9 = row 2 col 1)',
    );
    expect(shape!.kind, QuiltFaultKind.wrongShape);
    expect(
      [shape.needShape, shape.haveShape],
      [QuiltShape.wide, QuiltShape.square],
    );

    // Clue 7 is shape-only (square): a 1×2 patch around it is tall.
    final tall = QuiltRules.fault(
      puzzle,
      const QuiltRect(row: 1, col: 3, width: 1, height: 2),
    );
    expect(tall!.kind, QuiltFaultKind.wrongShape);
    expect(tall.haveShape, QuiltShape.tall);

    // The solution's own patches have no fault.
    for (final r in [a, b, c, d]) {
      expect(QuiltRules.fault(puzzle, r), isNull, reason: '$r');
    }
  });

  test('fault == null exactly when fits, for every rectangle on the grid', () {
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        for (var h = 1; row + h <= 4; h++) {
          for (var w = 1; col + w <= 4; w++) {
            final r = QuiltRect(row: row, col: col, width: w, height: h);
            expect(
              QuiltRules.fault(puzzle, r) == null,
              QuiltRules.fits(puzzle, r),
              reason: '$r',
            );
          }
        }
      }
    }
  });

  test('wrongPatches: a patch can fit its clue and still not belong', () {
    // The 2×2 in the bottom-right holds only clue 15 (area 4), so it fits — but the
    // answer is the 4×1 strip D, so it blocks the rest of the board.
    const fitsButWrong = QuiltRect(row: 2, col: 2, width: 2, height: 2);
    expect(QuiltRules.fits(puzzle, fitsButWrong), isTrue);
    expect(QuiltRules.wrongPatches(puzzle, [fitsButWrong]), [fitsButWrong]);

    // Right patches are never wrong; a clue-less one is.
    const stray = QuiltRect(row: 1, col: 0, width: 2, height: 1);
    expect(QuiltRules.wrongPatches(puzzle, [a, c]), isEmpty);
    expect(QuiltRules.wrongPatches(puzzle, [a, stray, c]), [stray]);
  });

  test('hintPlan: the most forced clue, with its number of placements', () {
    final plan = QuiltRules.hintPlan(puzzle, const [])!;
    // Clue 9 (area 4, wide) can only be the 4×1 along row 2: one placement.
    expect(plan.options, 1);
    expect(puzzle.solution[plan.clue], plan.rect);
    expect(QuiltRules.hint(puzzle, const []), plan.rect);
    expect(QuiltRules.hintPlan(puzzle, [a, b, c, d]), isNull, reason: 'solved');
  });
}
