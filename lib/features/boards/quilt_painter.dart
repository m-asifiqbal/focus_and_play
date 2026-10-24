// Draws the Quilt board: cells, stitched patches, the live drag preview, clues, the
// hint spotlight and the finishing "mosaic".
//
// What the player should read from the picture:
//  * while dragging, the preview already takes the clue's colour when the shape is
//    right, and stays a neutral grey while it isn't (never red — they're still drawing);
//  * a stitched patch that fits wears its clue's fabric colour; one that doesn't is
//    hatched red (hatching, not just colour, so it reads without colour vision);
//  * when the grid is solved the patches grow together into one picture.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../games/quilt/quilt.dart';
import 'quilt_controller.dart';

const kQuiltFabrics = [
  Color(0xFF9ED9B0),
  Color(0xFFFFD68A),
  Color(0xFFA9D3F5),
  Color(0xFFF7B6C2),
  Color(0xFFC9B8F5),
  Color(0xFFFFC2A1),
  Color(0xFFB6E3D4),
  Color(0xFFF2E394),
];

Color fabricOf(int clue) => kQuiltFabrics[clue % kQuiltFabrics.length];

/// Solid bars, so a tall shape can't be mistaken for a 0.
void drawShapeGlyph(
  Canvas canvas,
  Offset at,
  double size,
  QuiltShape shape,
  Color color,
) {
  final (w, h) = switch (shape) {
    QuiltShape.square => (size * .72, size * .72),
    QuiltShape.tall => (size * .42, size * .95),
    QuiltShape.wide => (size * .95, size * .42),
  };
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: w, height: h),
      Radius.circular(size * .12),
    ),
    Paint()..color = color,
  );
}

class QuiltPainter extends CustomPainter {
  QuiltPainter(
    this.c,
    this.st,
    this.mi,
    this.anim,
    this.win,
    this.mark,
    this.colourBlind,
    this.large,
    this.labels,
  ) : super(repaint: Listenable.merge([anim, win]));

  final QuiltController c;
  final IslandStyle st;
  final MiColors mi;

  /// Looping 0..1 clock for the marching ants and the hint pulse.
  final Animation<double> anim;

  /// 0 → 1 when the grid is solved: patches grow together, the grid fades.
  final Animation<double> win;
  final bool mark, colourBlind, large;

  /// Clue labels laid out once per size (owned and disposed by the board).
  final Map<String, TextPainter> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.n;
    final cell = size.width / n;
    final w = Curves.easeInOut.transform(win.value);
    // The merged picture keeps the card's rounded corners.
    if (w > 0) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(18 * w)),
      );
    }
    final inset = 3 * (1 - w);
    final radius = cell * .22 * (1 - w);
    Rect rectOf(QuiltRect r, [double i = 3]) => Rect.fromLTWH(
      r.col * cell + i,
      r.row * cell + i,
      r.width * cell - i * 2,
      r.height * cell - i * 2,
    );

    if (w < 1) {
      final tint = Paint()..color = st.tint.withValues(alpha: 1 - w);
      for (var i = 0; i < n * n; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              (i % n) * cell + 2,
              (i ~/ n) * cell + 2,
              cell - 4,
              cell - 4,
            ),
            Radius.circular(cell * .2),
          ),
          tint,
        );
      }
    }

    for (final r in c.placed) {
      final clue = QuiltRules.clueIn(c.puzzle, r);
      final fits = QuiltRules.fits(c.puzzle, r);
      final wrong = mark && !fits;
      final base = fits && clue != null
          ? fabricOf(clue)
          : (wrong
                ? Color.alphaBlend(mi.danger.withValues(alpha: .16), mi.card)
                : (mi.isNight
                      ? const Color(0xFF3A4A68)
                      : const Color(0xFFD9DEE5)));
      final rr = RRect.fromRectAndRadius(
        rectOf(r, inset),
        Radius.circular(radius),
      );
      canvas.drawRRect(rr, Paint()..color = base);
      if (colourBlind && fits && clue != null) {
        _hatch(
          canvas,
          rr,
          Colors.white.withValues(alpha: .45),
          8.0 + (clue % 3) * 4,
          clue.isEven,
        );
      }
      if (w < 1) {
        _dashedRect(
          canvas,
          rectOf(r, 8),
          cell * .14,
          Paint()
            ..color = Colors.white.withValues(alpha: 1 - w)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (wrong) {
        _hatch(canvas, rr, mi.danger.withValues(alpha: .5), 9, true);
        canvas.drawRRect(
          rr,
          Paint()
            ..color = mi.danger
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      if (c.hintRect == r && w < .5) {
        final t = (sin(anim.value * 2 * pi) + 1) / 2;
        canvas.drawRRect(
          rr.inflate(2 + t * 3),
          Paint()
            ..color = const Color(0xFFFFC233)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }

    final pv = c.preview;
    if (pv != null) _preview(canvas, pv, cell, rectOf(pv));

    // Clues fade out as the picture merges.
    if (w > 0) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 1 - w),
      );
    }
    for (final clue in c.puzzle.clues) {
      _clue(canvas, clue, cell, n);
    }
    if (w > 0) canvas.restore();

    final spot = c.spotlightClue;
    if (spot != null) {
      _spotlight(canvas, size, cell, n, c.puzzle.clues[spot].cell);
    }

    if (pv != null && pv.area > 1) _sizeBadge(canvas, pv, rectOf(pv));
    if (pv != null) {
      // Where the finger is: the fingertip hides the very square being chosen.
      final end = c.dragTo!;
      final at = Offset(
        (end % n) * cell + cell / 2,
        (end ~/ n) * cell + cell / 2,
      );
      canvas.drawCircle(
        at,
        cell * .26,
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
      canvas.drawCircle(
        at,
        cell * .26,
        Paint()
          ..color = st.ledge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    if (w > 0) canvas.restore();
  }

  /// The patch being dragged: clue-coloured and solid once it would be right.
  void _preview(Canvas canvas, QuiltRect pv, double cell, Rect box) {
    final clue = QuiltRules.clueIn(c.puzzle, pv);
    final fits = QuiltRules.fits(c.puzzle, pv);
    final fill = fits && clue != null ? fabricOf(clue) : mi.ink;
    final rr = RRect.fromRectAndRadius(box, Radius.circular(cell * .22));
    canvas.drawRRect(
      rr,
      Paint()..color = fill.withValues(alpha: fits ? .8 : .13),
    );
    final dash = Paint()
      ..color = fits && clue != null
          ? Color.lerp(fabricOf(clue), Colors.black, .4)!
          : st.ledge.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      for (var d = -20 + anim.value * 20; d < m.length; d += 20) {
        canvas.drawPath(m.extractPath(max(0, d), max(0, d + 10)), dash);
      }
    }
  }

  void _clue(Canvas canvas, QuiltClue clue, double cell, int n) {
    final at = Offset(
      (clue.cell % n) * cell + cell / 2,
      (clue.cell ~/ n) * cell + cell / 2,
    );
    final label = clue.area?.toString();
    final hasShape = clue.shape != null;
    final w = hasShape && label != null ? cell * .78 : cell * .58;
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: w, height: cell * .56),
      Radius.circular(cell * .28),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.white);
    if (!c.placed.any((r) => r.contains(clue.cell, n))) {
      canvas.drawRRect(
        pill,
        Paint()
          ..color = st.cardLedge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    var x = at.dx;
    if (hasShape && label != null) x -= cell * .16;
    if (hasShape) {
      drawShapeGlyph(
        canvas,
        Offset(label != null ? x : at.dx, at.dy),
        cell * .26,
        clue.shape!,
        const Color(0xFF13213C),
      );
    }
    if (label != null) {
      final size = cell * (large ? .42 : .34);
      final tp = labels.putIfAbsent(
        '$label@${size.toStringAsFixed(1)}',
        () => TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: MiFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: size,
              color: const Color(0xFF13213C),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final cx = hasShape ? at.dx + cell * .17 : at.dx;
      tp.paint(canvas, Offset(cx - tp.width / 2, at.dy - tp.height / 2));
    }
  }

  /// "Look here": everything but the hinted clue's square is dimmed and the square
  /// pulses in sun yellow.
  void _spotlight(Canvas canvas, Size size, double cell, int n, int clueCell) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (clueCell % n) * cell,
        (clueCell ~/ n) * cell,
        cell,
        cell,
      ).inflate(2),
      Radius.circular(cell * .24),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = mi.navy.withValues(alpha: .5),
    );
    final t = (sin(anim.value * 2 * pi) + 1) / 2;
    canvas.drawRRect(
      hole.inflate(1 + t * 3),
      Paint()
        ..color = const Color(0xFFFFC233)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _sizeBadge(Canvas canvas, QuiltRect pv, Rect r) {
    final tp = TextPainter(
      text: TextSpan(
        text: '${pv.width} × ${pv.height} = ${pv.area}',
        style: const TextStyle(
          fontFamily: MiFonts.body,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset(r.center.dx, max(14, r.top - 16)),
      width: tp.width + 16,
      height: 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(12)),
      Paint()..color = const Color(0xFF13213C),
    );
    tp.paint(
      canvas,
      Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2),
    );
    tp.dispose();
  }

  void _hatch(Canvas canvas, RRect rr, Color color, double step, bool rising) {
    canvas.save();
    canvas.clipRRect(rr);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = rr.left - rr.height; x < rr.right; x += step) {
      canvas.drawLine(
        rising ? Offset(x, rr.bottom) : Offset(x, rr.top),
        rising
            ? Offset(x + rr.height, rr.top)
            : Offset(x + rr.height, rr.bottom),
        p,
      );
    }
    canvas.restore();
  }

  void _dashedRect(Canvas canvas, Rect r, double radius, Paint p) {
    for (final m
        in (Path()
              ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))))
            .computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, min(m.length, d + 5)), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
