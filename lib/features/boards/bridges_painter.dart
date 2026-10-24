// Draws the Bridges board: the sea with faint guides where a bridge could go, the
// wooden bridges (one plank-line, or two), the round islets with their numbers, the
// hint spotlight and the finger's bridge while dragging.
//
// What the player should read from the picture:
//  * an islet that has exactly its number is filled solid; one that still needs
//    bridges is a white disc with a coloured rim; one with too many has a red rim;
//  * dashed guides show which islets can be joined, so nothing is hidden;
//  * a double bridge is two parallel planks, never a thicker single one.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import 'bridges_controller.dart';

/// A bridge the finger is drawing: from islet [from] to the point [to].
class BridgesDrag {
  const BridgesDrag(this.from, this.to);
  final int from;
  final Offset to;
}

class BridgesPainter extends CustomPainter {
  BridgesPainter(
    this.c,
    this.st,
    this.mi,
    this.anim,
    this.win,
    this.drag,
    this.mark,
    this.large,
    this.labels,
    this.semantics,
  ) : super(repaint: Listenable.merge([c, anim, win, drag]));

  final BridgesController c;
  final IslandStyle st;
  final MiColors mi;

  /// Looping clock for the hint pulse.
  final Animation<double> anim;

  /// 0 → 1 when solved: the islets bounce one after another.
  final Animation<double> win;
  final ValueNotifier<BridgesDrag?> drag;
  final bool mark, large;

  /// Number labels laid out once per size (owned and disposed by the board).
  final Map<String, TextPainter> labels;

  /// Screen-reader nodes (one per possible bridge), built by the board.
  final SemanticsBuilderCallback? semantics;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => semantics;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => true;

  Color get _wood =>
      mi.isNight ? const Color(0xFFD9A25E) : const Color(0xFF9A6A3A);
  Color get _woodDark =>
      mi.isNight ? const Color(0xFF8A5A2B) : const Color(0xFF6B4423);

  @override
  void paint(Canvas canvas, Size size) {
    final p = c.puzzle;
    final cell = size.width / p.cols;
    final r = cell * .36; // islet radius
    Offset at(int i) =>
        Offset((p.islands[i].col + .5) * cell, (p.islands[i].row + .5) * cell);

    // Sea, with a dot at every grid point so the layout reads.
    final sea = RRect.fromRectAndRadius(
      Offset.zero & Size(size.width, cell * p.rows),
      Radius.circular(cell * .3),
    );
    canvas.drawRRect(sea, Paint()..color = st.cell);
    if (st.isNight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & Size(size.width, cell * p.rows)).deflate(.8),
          Radius.circular(cell * .3),
        ),
        Paint()
          ..color = st.cellEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    final dot = Paint()..color = st.ink.withValues(alpha: .18);
    for (var row = 0; row < p.rows; row++) {
      for (var col = 0; col < p.cols; col++) {
        canvas.drawCircle(
          Offset((col + .5) * cell, (row + .5) * cell),
          1.6,
          dot,
        );
      }
    }

    // Guides: where a bridge could go and none is built yet.
    final guide = Paint()
      ..color = st.ink.withValues(alpha: .34)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in c.pairs) {
      if (c.bridgesBetween(a, b) > 0) continue;
      _dashed(canvas, at(a), at(b), guide, 7, 6);
    }

    // After a refused tap: a red halo under the bridge that is in the way.
    final blocker = c.blockedBy;
    if (blocker != null) {
      canvas.drawLine(
        at(blocker.$1),
        at(blocker.$2),
        Paint()
          ..color = mi.danger.withValues(alpha: .5)
          ..strokeWidth = cell * .36
          ..strokeCap = StrokeCap.round,
      );
    }

    // Bridges.
    final glow = (sin(anim.value * 2 * pi) + 1) / 2;
    for (final l in c.links) {
      final a = at(l.a), b = at(l.b);
      final dir = (b - a) / (b - a).distance;
      final nrm = Offset(-dir.dy, dir.dx);
      final offsets = l.count == 1 ? const [0.0] : [-cell * .1, cell * .1];
      if (c.hintLink == (l.a, l.b)) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xFFFFC233)
                .withValues(alpha: .55 + .35 * glow)
            ..strokeWidth = cell * (l.count == 1 ? .3 : .42) + glow * 4
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final o in offsets) {
        final from = a + nrm * o, to = b + nrm * o;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = _woodDark
            ..strokeWidth = cell * .15
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = _wood
            ..strokeWidth = cell * .1
            ..strokeCap = StrokeCap.round,
        );
        // Planks: short cross-ticks along the span.
        final len = (to - from).distance;
        final tick = Paint()
          ..color = _woodDark.withValues(alpha: .8)
          ..strokeWidth = 1.2;
        for (var d = r; d < len - r; d += cell * .16) {
          final q = from + dir * d;
          canvas.drawLine(q + nrm * cell * .05, q - nrm * cell * .05, tick);
        }
      }
    }

    // ...and the bridge that was tried, dashed in red.
    final tried = c.blockedTry;
    if (tried != null) {
      _dashed(
        canvas,
        at(tried.$1),
        at(tried.$2),
        Paint()
          ..color = mi.danger
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
        8,
        6,
      );
    }

    // The bridge being dragged out.
    final dr = drag.value;
    if (dr != null) {
      _dashed(
        canvas,
        at(dr.from),
        dr.to,
        Paint()
          ..color = st.color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
        9,
        6,
      );
      canvas.drawCircle(
        dr.to,
        cell * .16,
        Paint()..color = st.color.withValues(alpha: .7),
      );
    }

    // Islets.
    final degrees = c.degrees;
    final w = Curves.easeInOut.transform(win.value);
    for (var i = 0; i < p.islands.length; i++) {
      final need = p.islands[i].need;
      final have = degrees[i];
      final done = have == need;
      final over = have > need;
      // Win bounce: each islet pops in turn.
      final pop = w > 0
          ? 1 + .22 * sin(pi * (w * 1.6 - i * .06).clamp(0.0, 1.0))
          : 1.0;
      final centre = at(i);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(pop);
      canvas.drawCircle(
        const Offset(0, 3),
        r,
        Paint()
          ..color = (done ? st.ledge : st.cardLedge).withValues(
            alpha: mi.isNight ? .9 : 1,
          ),
      );
      final fill = done
          ? st.color
          : (mi.isNight ? const Color(0xFF1B2A44) : Colors.white);
      canvas.drawCircle(Offset.zero, r, Paint()..color = fill);
      final rim = over && mark ? mi.danger : st.color;
      canvas.drawCircle(
        Offset.zero,
        r - 1.5,
        Paint()
          ..color = rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = over && mark ? 4 : 3,
      );
      final textColour = done
          ? st.onColor
          : (over && mark ? mi.danger : mi.ink);
      final size0 = r * (large ? 1.25 : 1.05);
      final key = '$need@${size0.toStringAsFixed(1)}@${textColour.toARGB32()}';
      final tp = labels.putIfAbsent(
        key,
        () => TextPainter(
          text: TextSpan(
            text: '$need',
            style: TextStyle(
              fontFamily: MiFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: size0,
              color: textColour,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Spotlight: dim everything but the hinted islet, which pulses.
    final spot = c.spotlightIsland;
    if (spot != null) {
      final hole = at(spot);
      // Clipped to the sea so the dimming keeps the board's rounded corners.
      canvas.save();
      canvas.clipRRect(sea);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addOval(Rect.fromCircle(center: hole, radius: r + 5)),
        ),
        Paint()..color = mi.navy.withValues(alpha: .45),
      );
      canvas.restore();
      canvas.drawCircle(
        hole,
        r + 5 + glow * 3,
        Paint()
          ..color = const Color(0xFFFFC233)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }

  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    for (var t = 0.0; t < len; t += dash + gap) {
      canvas.drawLine(a + dir * t, a + dir * min(t + dash, len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
