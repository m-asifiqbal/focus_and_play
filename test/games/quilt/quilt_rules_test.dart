// Quilt rules tests: clueIn, fits, isSolved, hints and the rectangle helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/quilt/quilt.dart';

void main() {
  // A hand-made 4×4 puzzle:
  //   A A B B      A = 2×2 square at (0,0), clue area 4 on cell 0
  //   A A B B      B = 2×2 at (0,2), clue "square" (shape only) on cell 7
  //   C C C C      C = 4×1 wide at (2,0), clue area 4 + wide on cell 9
  //   D D D D      D = 4×1 wide at (3,0), clue area 4 on cell 15
  const a = QuiltRect(row: 0, col: 0, width: 2, height: 2);
  const b = QuiltRect(row: 0, col: 2, width: 2, height: 2);
  const c = QuiltRect(row: 2, col: 0, width: 4, height: 1);
  const d = QuiltRect(row: 3, col: 0, width: 4, height: 1);
  final small = QuiltPuzzle(
    size: 4,
    clues: const [
      QuiltClue(cell: 0, area: 4),
      QuiltClue(cell: 7, shape: QuiltShape.square),
      QuiltClue(cell: 9, area: 4, shape: QuiltShape.wide),
      QuiltClue(cell: 15, area: 4),
    ],
    solution: const [a, b, c, d],
  );

  test('rectangle helpers', () {
    expect(a.area, 4);
    expect(a.shape, QuiltShape.square);
    expect(c.shape, QuiltShape.wide);
    expect(
      const QuiltRect(row: 0, col: 0, width: 1, height: 3).shape,
      QuiltShape.tall,
    );
    expect(a.cells(4).toList(), [0, 1, 4, 5]);
    expect(a.contains(5, 4), isTrue);
    expect(a.contains(2, 4), isFalse);
    expect(
      QuiltRect.spanning(10, 1, 4),
      const QuiltRect(row: 0, col: 1, width: 2, height: 3),
    );
    expect(a.overlaps(b), isFalse);
    expect(
      a.overlaps(const QuiltRect(row: 1, col: 1, width: 2, height: 2)),
      isTrue,
    );
    // Built at run time so it is a distinct object, not the same const.
    final same = QuiltRect(row: 0, col: a.col, width: 2, height: 2);
    expect(identical(a, same), isFalse);
    expect(a == same, isTrue);
    expect(same.hashCode, a.hashCode);
    expect({a, same}.length, 1);
    expect(
      const QuiltRect(row: 3, col: 3, width: 2, height: 1).isInside(4),
      isFalse,
    );
  });

  test('the hand-made puzzle is unique', () {
    expect(QuiltSolver.countSolutions(4, small.clues), 1);
    expect(QuiltRules.isSolved(small, small.solution), isTrue);
  });

  test('clueIn finds exactly one clue or nothing', () {
    expect(QuiltRules.clueIn(small, a), 0);
    expect(QuiltRules.clueIn(small, b), 1);
    // No clue inside.
    expect(
      QuiltRules.clueIn(
        small,
        const QuiltRect(row: 0, col: 1, width: 1, height: 2),
      ),
      isNull,
    );
    // Two clues inside.
    expect(
      QuiltRules.clueIn(
        small,
        const QuiltRect(row: 0, col: 0, width: 4, height: 2),
      ),
      isNull,
    );
  });

  test('fits checks clue count, area, shape and bounds', () {
    for (final r in small.solution) {
      expect(QuiltRules.fits(small, r), isTrue, reason: '$r');
    }
    // Holds only the area+wide clue on cell 9, with the right area but tall.
    expect(
      QuiltRules.fits(
        small,
        const QuiltRect(row: 0, col: 1, width: 1, height: 4),
      ),
      isFalse, // area 4 but tall, not wide
    );
    // Shape-only square: any square holding just that clue fits, whatever its area.
    expect(
      QuiltRules.fits(
        small,
        const QuiltRect(row: 1, col: 3, width: 1, height: 1),
      ),
      isTrue,
    );
    expect(
      QuiltRules.fits(
        small,
        const QuiltRect(row: 1, col: 2, width: 2, height: 1),
      ),
      isFalse, // wide, not square
    );
    // Wrong area for the area-only clue on cell 0.
    expect(
      QuiltRules.fits(
        small,
        const QuiltRect(row: 0, col: 0, width: 2, height: 1),
      ),
      isFalse,
    );
    // Outside the grid.
    expect(
      QuiltRules.fits(
        small,
        const QuiltRect(row: 3, col: 0, width: 5, height: 1),
      ),
      isFalse,
    );
  });

  test('isSolved rejects gaps, overlaps and non-fitting patches', () {
    expect(QuiltRules.isSolved(small, const []), isFalse);
    expect(QuiltRules.isSolved(small, const [a, b, c]), isFalse); // gap
    expect(
      QuiltRules.isSolved(small, const [a, b, c, d, d]),
      isFalse,
    ); // overlap
    // Covers everything with fitting patches except one that doesn't fit.
    expect(
      QuiltRules.isSolved(small, const [
        a,
        QuiltRect(row: 0, col: 2, width: 2, height: 1),
        QuiltRect(row: 1, col: 2, width: 2, height: 1),
        c,
        d,
      ]),
      isFalse,
    );
    // Order of the placed patches doesn't matter.
    expect(QuiltRules.isSolved(small, const [d, c, b, a]), isTrue);
  });

  test('generated puzzles: isSolved on the solution, not on a broken one', () {
    for (final n in [5, 6, 7, 8]) {
      final p = QuiltGenerator.generate(
        QuiltParams(size: n, maxArea: 9, shapeClues: 0.5, shapeOnly: 0.5),
        n,
      );
      expect(QuiltRules.isSolved(p, p.solution), isTrue);
      for (final r in p.solution) {
        expect(QuiltRules.fits(p, r), isTrue);
      }
      expect(QuiltRules.isSolved(p, p.solution.sublist(1)), isFalse);
      // Grow the first patch by a row or a column: it now overlaps or leaves the grid.
      final r = p.solution.first;
      final grown = QuiltRect(
        row: r.row,
        col: r.col,
        width: r.width + (r.col + r.width < n ? 1 : 0),
        height: r.height + (r.col + r.width < n ? 0 : 1),
      );
      expect(
        QuiltRules.isSolved(p, [grown, ...p.solution.sublist(1)]),
        isFalse,
      );
    }
  });

  test('hint on an empty board picks the most constrained clue', () {
    final h = QuiltRules.hint(small, const []);
    expect(h, isNotNull);
    expect(small.solution, contains(h));
    // The area+wide clue on cell 9 has the fewest placements (only row 2 fits it).
    final counts = [
      for (var i = 0; i < small.clues.length; i++)
        QuiltSolver.candidatesFor(4, small.clues, i).length,
    ];
    final fewest = counts.indexOf(counts.reduce((x, y) => x < y ? x : y));
    expect(h, small.solution[fewest]);
  });

  test(
    'hint skips placed patches, ignores wrong ones, and is null when solved',
    () {
      expect(QuiltRules.hint(small, const [a, b, c, d]), isNull);
      final h1 = QuiltRules.hint(small, const [c]);
      expect(h1, isNot(c));
      expect(small.solution, contains(h1));
      // A wrong patch on the board doesn't count as placed.
      final wrong = const QuiltRect(row: 0, col: 0, width: 2, height: 1);
      final h2 = QuiltRules.hint(small, [wrong, b, c, d]);
      expect(h2, a);
      // Generated puzzles: following hints solves the board.
      for (final n in [5, 6, 7, 8]) {
        final p = QuiltGenerator.generate(
          QuiltParams(size: n, maxArea: 9, shapeClues: 0.6, shapeOnly: 0.5),
          n * 3,
        );
        final placed = <QuiltRect>[];
        for (var step = 0; step < p.solution.length; step++) {
          final h = QuiltRules.hint(p, placed);
          expect(h, isNotNull);
          expect(p.solution, contains(h));
          expect(placed, isNot(contains(h)));
          placed.add(h!);
        }
        expect(QuiltRules.isSolved(p, placed), isTrue);
        expect(QuiltRules.hint(p, placed), isNull);
      }
    },
  );

  test('solver sees ambiguity', () {
    // 2×2 with two area-2 clues on a diagonal: two dominoes either way.
    expect(
      QuiltSolver.countSolutions(2, const [
        QuiltClue(cell: 0, area: 2),
        QuiltClue(cell: 3, area: 2),
      ]),
      2,
    );
    // Same, but the first clue says wide: only the horizontal split is left.
    expect(
      QuiltSolver.countSolutions(2, const [
        QuiltClue(cell: 0, area: 2, shape: QuiltShape.wide),
        QuiltClue(cell: 3, area: 2),
      ]),
      1,
    );
    // Areas that can't add up: no solution.
    expect(
      QuiltSolver.countSolutions(2, const [QuiltClue(cell: 0, area: 3)]),
      0,
    );
  });
}
