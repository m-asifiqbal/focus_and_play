// Sunrise sea with the four islands on the horizon and Pip sailing in.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/mi_art.dart';

class WelcomeScene extends StatefulWidget {
  const WelcomeScene({super.key});
  @override
  State<WelcomeScene> createState() => _WelcomeSceneState();
}

class _WelcomeSceneState extends State<WelcomeScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final horizon = h * .62;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value * 2 * pi;
          final rockY = sin(v) * 5;
          final rockA = sin(v) * .035;
          return Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned.fill(child: CustomPaint(painter: _ScenePainter(v, horizon))),
            Positioned(
              left: w / 2 - 105,
              top: horizon + h * .02 + rockY,
              child: Transform.rotate(
                angle: rockA,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 210,
                  height: 170,
                  child: Stack(clipBehavior: Clip.none, children: [
                    const Positioned(left: 30, top: 34, child: Pip(size: 78)),
                    Positioned.fill(child: CustomPaint(painter: _BoatPainter())),
                  ]),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.v, this.horizon);
  final double v;
  final double horizon;

  Paint _f(int c) => Paint()..color = Color(c);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, _f(0xFFFFEFD6));
    final sun = Offset(s.width * .75, horizon * .45);
    final pulse = 1 + .05 * sin(v);
    canvas.drawCircle(sun, 92 * pulse, Paint()..color = const Color(0xFFFFE29A).withValues(alpha: .55));
    canvas.drawCircle(sun, 70 * pulse, Paint()..color = const Color(0xFFFFD66B).withValues(alpha: .7));
    canvas.drawCircle(sun, 52, _f(0xFFFFC233));
    _cloud(canvas, Offset(s.width * .22 + sin(v) * 14, horizon * .3), 1);
    _cloud(canvas, Offset(s.width * .53 - sin(v) * 10, horizon * .18), .7);
    final bird = Paint()
      ..color = const Color(0xFF13213C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final o in [Offset(s.width * .31, horizon * .52), Offset(s.width * .38, horizon * .48)]) {
      final p = o + Offset(sin(v) * 10, cos(v) * 4);
      final f = sin(v * 4) * 2;
      canvas.drawPath(Path()..moveTo(p.dx - 9, p.dy)..quadraticBezierTo(p.dx - 4, p.dy - 6 - f, p.dx, p.dy)..quadraticBezierTo(p.dx + 4, p.dy - 6 - f, p.dx + 9, p.dy), bird);
    }
    canvas.drawRect(Rect.fromLTWH(0, horizon, s.width, s.height - horizon), _f(0xFF3FA9D6));
    canvas.drawRect(Rect.fromLTWH(0, horizon, s.width, 14), _f(0xFF2E95C4));
    final step = s.width / 4;
    final cols = [0xFFF0582A, 0xFF1F9D55, 0xFF8A4FD8, 0xFF1E9BDC];
    for (var i = 0; i < 4; i++) {
      final cx = step * i + step / 2;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, horizon + 2), width: 76, height: 12), _f(i == 3 ? 0xFFDCE8F5 : 0xFFEAD3A6));
      final p = switch (i) {
        0 => (Path()..moveTo(cx - 26, horizon + 2)..lineTo(cx - 6, horizon - 34)..lineTo(cx + 6, horizon - 34)..lineTo(cx + 26, horizon + 2)..close()),
        1 => (Path()..moveTo(cx - 32, horizon + 2)..quadraticBezierTo(cx, horizon - 40, cx + 32, horizon + 2)..close()),
        2 => (Path()..moveTo(cx - 14, horizon + 2)..lineTo(cx - 10, horizon - 20)..lineTo(cx - 4, horizon - 26)..lineTo(cx + 2, horizon - 20)..lineTo(cx, horizon + 2)..moveTo(cx, horizon + 2)..lineTo(cx + 6, horizon - 36)..lineTo(cx + 12, horizon - 42)..lineTo(cx + 18, horizon - 36)..lineTo(cx + 15, horizon + 2)..close()),
        _ => (Path()..moveTo(cx - 34, horizon + 2)..lineTo(cx - 10, horizon - 32)..lineTo(cx + 4, horizon - 14)..lineTo(cx + 16, horizon - 28)..lineTo(cx + 34, horizon + 2)..close()),
      };
      canvas.drawPath(p, _f(cols[i]));
    }
    for (final (y, c, sp) in [(horizon + 40, 0xFF7CCBEA, 1.0), (horizon + 78, 0xFF8FD3EC, 1.4), (s.height - 30, 0xFF7CCBEA, 1.8)]) {
      final path = Path();
      final off = (v * 20 * sp) % 40;
      path.moveTo(-40 + off, y);
      for (var x = -40.0 + off; x < s.width + 40; x += 40) {
        path.relativeQuadraticBezierTo(10, -6, 20, 0);
        path.relativeQuadraticBezierTo(10, 6, 20, 0);
      }
      canvas.drawPath(path, Paint()
        ..color = Color(c)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }
  }

  void _cloud(Canvas c, Offset at, double s) {
    final w = Paint()..color = Colors.white.withValues(alpha: .95);
    c.drawOval(Rect.fromCenter(center: at.translate(0, 6 * s), width: 68 * s, height: 18 * s), w);
    c.drawCircle(at.translate(-14 * s, 0), 12 * s, w);
    c.drawCircle(at.translate(4 * s, -7 * s), 16 * s, w);
    c.drawCircle(at.translate(20 * s, s), 11 * s, w);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.v != v || old.horizon != horizon;
}

/// Boat in a 210×170 box: hull at the bottom, mast and sail behind Pip on the right.
class _BoatPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final mastX = 110.0;
    c.drawLine(Offset(mastX, 118), Offset(mastX, 0), Paint()
      ..color = const Color(0xFF13213C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    c.drawPath(Path()..moveTo(mastX, 6)..lineTo(mastX + 22, 13)..lineTo(mastX, 20)..close(), Paint()..color = const Color(0xFF0A7C70));
    c.drawPath(Path()..moveTo(mastX + 4, 8)..lineTo(mastX + 64, 112)..lineTo(mastX + 4, 112)..close(), Paint()..color = Colors.white);
    final logo = [const Color(0xFFF0582A), const Color(0xFF1F9D55), const Color(0xFF8A4FD8), const Color(0xFF1E9BDC)];
    for (var i = 0; i < 4; i++) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mastX + 14 + (i % 2) * 14, 74 + (i ~/ 2) * 14, 12, 12), const Radius.circular(4)), Paint()..color = logo[i]);
    }
    final hull = Path()..moveTo(8, 112)..lineTo(202, 112)..lineTo(178, 150)..lineTo(32, 150)..close();
    c.drawPath(hull, Paint()..color = const Color(0xFFB93C14));
    c.drawLine(const Offset(14, 122), const Offset(196, 122), Paint()
      ..color = Colors.white
      ..strokeWidth = 4);
    for (final x in [62.0, 105.0, 148.0]) {
      c.drawCircle(Offset(x, 136), 5, Paint()..color = const Color(0xFFFFE5D9));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
