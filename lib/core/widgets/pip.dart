// Pip the puffin — the game's guide — drawn in code so every part can move.
//
// Why not the SVG: a flat image can only be shifted as a whole, and a character
// that doesn't blink or breathe reads as a sticker. This draws the same shapes
// (same colours and proportions as assets/images/pip.svg) and animates them:
//   * breathing + a small bob, and a slow weight shift side to side;
//   * eyes that wander a little and blink (sometimes twice);
//   * a wing flap every few seconds, a foot tap, a fluttering scarf tail;
//   * tap him and he hops and flaps.
// Everything is a pure function of one looping clock, so it costs one repaint per
// frame and nothing else. With reduce motion he holds a still pose.

import 'dart:math';

import 'package:flutter/material.dart';

/// Length of the idle loop in seconds; all the little events sit inside it.
const _loopSeconds = 12.0;

class Pip extends StatefulWidget {
  const Pip({super.key, this.size = 64, this.hopsWhenTapped = true});
  final double size;

  /// Tapping Pip makes him hop and flap.
  final bool hopsWhenTapped;

  @override
  State<Pip> createState() => _PipState();
}

class _PipState extends State<Pip> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
      _clock.value = 0;
    } else if (!_clock.isAnimating) {
      // Each Pip starts at its own point of the loop, so several on screen
      // don't blink and flap in step.
      _clock.value = (identityHashCode(this) % 997) / 997;
      _clock.repeat(period: const Duration(seconds: 12));
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!widget.hopsWhenTapped || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _hop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: GestureDetector(
      onTap: _onTap,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(widget.size, widget.size * 130 / 120),
          painter: _PipPainter(_clock, _hop),
        ),
      ),
    ),
  );
}

class _PipPainter extends CustomPainter {
  _PipPainter(this.clock, this.hop)
    : super(repaint: Listenable.merge([clock, hop]));
  final Animation<double> clock, hop;

  static const _dark = Color(0xFF1B2A44);
  static const _wing = Color(0xFF2A3A57);
  static const _orange = Color(0xFFF0582A);
  static const _teal = Color(0xFF0A7C70);
  static const _ink = Color(0xFF13213C);

  /// 0..1 while an eyelid is closing and opening (a quick blink, twice at 6 s).
  double _blink(double t) {
    for (final s in const [2.4, 6.1, 6.55, 10.0]) {
      final u = (t - s) / .18;
      if (u >= 0 && u <= 1) return sin(pi * u);
    }
    return 0;
  }

  /// 0..1 strength of the wing flap (quick beats inside a one-second envelope).
  double _flap(double t) {
    for (final s in const [4.0, 9.2]) {
      final u = (t - s) / 1.0;
      if (u >= 0 && u <= 1) {
        return sin(pi * u) * (.55 + .45 * sin(u * pi * 6).abs());
      }
    }
    return 0;
  }

  /// 0..1 lift of the right foot: two little taps.
  double _tap(double t) {
    final u = (t - 7.0) / .9;
    return u >= 0 && u <= 1 ? max(0.0, sin(u * pi * 4)) : 0;
  }

  Path _body() => Path()
    ..moveTo(60, 14)
    ..cubicTo(30, 14, 18, 40, 18, 70)
    ..cubicTo(18, 100, 36, 118, 60, 118)
    ..cubicTo(84, 118, 102, 100, 102, 70)
    ..cubicTo(102, 40, 90, 14, 60, 14)
    ..close();

  Path _leftWing() => Path()
    ..moveTo(20, 64)
    ..cubicTo(8, 74, 9, 92, 21, 100)
    ..cubicTo(25, 88, 25, 76, 20, 64)
    ..close();

  Path _rightWing() => Path()
    ..moveTo(100, 64)
    ..cubicTo(112, 74, 111, 92, 99, 100)
    ..cubicTo(95, 88, 95, 76, 100, 64)
    ..close();

  Path _face() => Path()
    ..moveTo(30, 46)
    ..cubicTo(30, 30, 44, 24, 60, 24)
    ..cubicTo(76, 24, 90, 30, 90, 46)
    ..cubicTo(90, 60, 78, 66, 60, 66)
    ..cubicTo(42, 66, 30, 60, 30, 46)
    ..close();

  Path _scarf() => Path()
    ..moveTo(38, 64)
    ..quadraticBezierTo(60, 77, 82, 64)
    ..lineTo(81, 71)
    ..quadraticBezierTo(60, 84, 39, 71)
    ..close();

  Path _scarfTail() => Path()
    ..moveTo(74, 70)
    ..lineTo(84, 82)
    ..lineTo(77, 83)
    ..close();

  Path _beak() => Path()
    ..moveTo(49, 51)
    ..cubicTo(52, 47, 68, 47, 71, 51)
    ..cubicTo(70, 61, 64, 68, 60, 70)
    ..cubicTo(56, 68, 50, 61, 49, 51)
    ..close();

  Path _tuft() => Path()
    ..moveTo(57, 15)
    ..cubicTo(54, 7, 61, 3, 64, 7)
    ..cubicTo(61.5, 8, 61, 11, 62, 15)
    ..close();

  void _rotateAbout(Canvas c, double x, double y, double angle) {
    c.translate(x, y);
    c.rotate(angle);
    c.translate(-x, -y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _loopSeconds;
    final h = hop.value;
    final jump = sin(pi * h); // 0 → 1 → 0 over the hop
    final breathe = sin(2 * pi * t / 2.6);
    // Squash on take-off and landing.
    final squash = h > 0 && h < .15
        ? (.15 - h) / .15
        : (h > .85 ? (h - .85) / .15 : 0.0);

    canvas.save();
    canvas.scale(size.width / 120);

    // Shadow stays on the ground and shrinks as Pip leaves it.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(60, 124),
        width: 60 * (1 - .3 * jump),
        height: 10 * (1 - .3 * jump),
      ),
      Paint()..color = Colors.black.withValues(alpha: .15 * (1 - .4 * jump)),
    );

    canvas.translate(0, -17 * jump); // the hop
    final lift = _tap(t);
    final footPaint = Paint()..color = _orange;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(45, 118), width: 22, height: 11),
      footPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(75, 118 - 3.2 * lift),
        width: 22,
        height: 11,
      ),
      footPaint,
    );

    // The whole bird: weight shift, breathing (grows from the feet) and squash.
    canvas.save();
    _rotateAbout(canvas, 60, 118, .03 * sin(2 * pi * t / 6.5));
    canvas.translate(60, 118);
    canvas.scale(
      1 + .012 * breathe * -1 + .08 * squash,
      1 + .022 * breathe - .1 * squash,
    );
    canvas.translate(-60, -118 - 1.2 * (breathe + 1) / 2);

    canvas.drawPath(_body(), Paint()..color = _dark);

    // Wings: a slight sway, flapping out now and then (and on the hop).
    final flap = max(_flap(t), jump * .9);
    final wingAngle = .06 * sin(2 * pi * t / 2.6 + 1) + flap * .55;
    final wingPaint = Paint()..color = _wing;
    canvas.save();
    _rotateAbout(canvas, 21, 66, wingAngle);
    canvas.drawPath(_leftWing(), wingPaint);
    canvas.restore();
    canvas.save();
    _rotateAbout(canvas, 99, 66, -wingAngle);
    canvas.drawPath(_rightWing(), wingPaint);
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 90), width: 56, height: 52),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(_face(), Paint()..color = const Color(0xFFF4F7FB));

    canvas.drawPath(_scarf(), Paint()..color = _teal);
    canvas.save();
    _rotateAbout(canvas, 74, 70, .18 * sin(2 * pi * t / 1.2));
    canvas.drawPath(_scarfTail(), Paint()..color = _teal);
    canvas.restore();

    // Eyes wander a little, blink, and squint happily when Pip hops.
    final close = max(_blink(t), jump * .7).clamp(0.0, 1.0);
    final look = Offset(1.5 * sin(t * .9), .6 * sin(t * .6 + 1));
    for (final cx in const [47.0, 73.0]) {
      canvas.save();
      canvas.translate(cx + look.dx, 44 + look.dy);
      canvas.scale(1, 1 - .9 * close);
      canvas.drawCircle(Offset.zero, 6, Paint()..color = _ink);
      if (close < .5) {
        canvas.drawCircle(
          const Offset(2, -2),
          2,
          Paint()..color = Colors.white,
        );
      }
      canvas.restore();
    }

    final cheek = Paint()
      ..color = const Color(0xFFFFB3A0).withValues(alpha: .85);
    canvas.drawCircle(const Offset(37, 54), 4.5, cheek);
    canvas.drawCircle(const Offset(83, 54), 4.5, cheek);

    canvas.drawPath(_beak(), Paint()..color = _orange);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(50.5, 53)
        ..cubicTo(55, 50, 65, 50, 69.5, 53),
      stroke
        ..color = const Color(0xFFFFC233)
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      Path()
        ..moveTo(53, 59)
        ..cubicTo(56.5, 57.5, 63.5, 57.5, 67, 59),
      stroke
        ..color = const Color(0xFFB93C14)
        ..strokeWidth = 2,
    );
    canvas.drawPath(_tuft(), Paint()..color = _dark);

    canvas.restore(); // the whole bird
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
