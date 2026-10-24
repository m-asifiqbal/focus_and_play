// Little island diorama for Home cards and the island picker: sea, a sandy
// ring with foam, the island's landmark, and a dotted trail. Gently animated.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/game_id.dart';

class MiniIsland extends StatefulWidget {
  const MiniIsland({
    super.key,
    required this.game,
    this.night = false,
    this.height = 70,
  });
  final GameId game;
  final bool night;
  final double height;

  @override
  State<MiniIsland> createState() => _MiniIslandState();
}

class _MiniIslandState extends State<MiniIsland>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

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
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _MiniPainter(widget.game, widget.night, _c),
      ),
    ),
  );
}

class _MiniPainter extends CustomPainter {
  _MiniPainter(this.game, this.night, this.t) : super(repaint: t);
  final GameId game;
  final bool night;
  final Animation<double> t;

  Paint _f(int c) => Paint()..color = Color(c);
  Path _poly(List<double> xy) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Design space 152×70, scaled to fit (never cropped) and centred on the sea.
    final s = min(size.width / 152, size.height / 70);
    canvas.drawRect(Offset.zero & size, _f(night ? 0xFF12304E : 0xFF86CFEA));
    canvas.save();
    canvas.translate((size.width - 152 * s) / 2, (size.height - 70 * s) / 2);
    canvas.scale(s);
    final v = t.value * 2 * pi;
    final bob = sin(v) * 1.6;

    final wave = Paint()
      ..color = Colors.white.withValues(alpha: .35 + .35 * (sin(v * 2) + 1) / 2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(8, 20)
        ..relativeQuadraticBezierTo(5, -4, 10, 0)
        ..relativeQuadraticBezierTo(5, 4, 10, 0),
      wave,
    );
    canvas.drawPath(
      Path()
        ..moveTo(126, 62)
        ..relativeQuadraticBezierTo(5, -4, 10, 0)
        ..relativeQuadraticBezierTo(5, 4, 10, 0),
      wave,
    );

    final frost = game == GameId.sudoku;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(76, 54), width: 128, height: 28),
      _f(frost ? 0xFFC9D8E8 : 0xFFEAD3A6),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(76, 54), width: 128, height: 28),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final ground = switch (game) {
      GameId.thread => 0xFFC9A98F,
      GameId.quilt => 0xFF8ACB8E,
      GameId.twist => 0xFFB9A6E8,
      GameId.sudoku => 0xFFE3EEF8,
      GameId.sleuth => 0xFFE2C4D2,
      GameId.bridges => 0xFF9EDBC8,
    };
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(76, 52), width: 108, height: 20),
      _f(ground),
    );

    canvas.save();
    canvas.translate(0, bob);
    switch (game) {
      case GameId.thread:
        canvas.drawPath(
          _poly([48, 52, 69, 17, 83, 17, 104, 52]),
          _f(0xFF8A4B3A),
        );
        canvas.drawPath(_poly([58, 52, 72, 28, 76, 52]), _f(0xFF74402F));
        final glow = .7 + .3 * (sin(v * 2) + 1) / 2;
        canvas.drawPath(
          _poly([69, 17, 83, 17, 79, 25, 76, 21, 72, 27]),
          Paint()..color = const Color(0xFFF0582A).withValues(alpha: glow),
        );
        canvas.drawPath(
          Path()
            ..moveTo(77, 25)
            ..cubicTo(76, 33, 80, 38, 78, 46),
          Paint()
            ..color = const Color(0xFFF0582A).withValues(alpha: glow)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      case GameId.quilt:
        canvas.drawPath(
          Path()
            ..moveTo(36, 52)
            ..quadraticBezierTo(76, 8, 116, 52)
            ..close(),
          _f(0xFF4FA562),
        );
        canvas.drawPath(
          _poly([52, 46, 68, 34, 80, 42, 64, 52]),
          _f(0xFFB6E7C6),
        );
        canvas.drawPath(
          _poly([80, 42, 94, 34, 106, 46, 92, 52]),
          _f(0xFFFFD68A),
        );
        canvas.drawPath(
          _poly([68, 34, 78, 26, 92, 32, 80, 42]),
          _f(0xFF7FD39B),
        );
      case GameId.twist:
        canvas.drawPath(
          _poly([50, 52, 56, 30, 64, 22, 71, 30, 68, 52]),
          _f(0xFF8A4FD8),
        );
        canvas.drawPath(
          _poly([68, 52, 75, 16, 83, 8, 91, 16, 87, 52]),
          _f(0xFFB48AF0),
        );
        canvas.drawPath(
          _poly([87, 52, 91, 34, 97, 28, 103, 34, 101, 52]),
          _f(0xFF6B35C4),
        );
        canvas.drawPath(
          _poly([75, 16, 83, 8, 83, 52, 75, 52]),
          Paint()..color = Colors.white.withValues(alpha: .25),
        );
      case GameId.sudoku:
        canvas.drawPath(
          _poly([32, 52, 60, 16, 76, 36, 92, 20, 122, 52]),
          _f(0xFF1E9BDC),
        );
        canvas.drawPath(
          _poly([60, 16, 69, 28, 64, 26, 60, 30, 56, 26, 51, 28]),
          _f(0xFFFFFFFF),
        );
        canvas.drawPath(
          _poly([92, 20, 100, 30, 95, 29, 91, 32, 87, 28, 84, 30]),
          _f(0xFFFFFFFF),
        );
        canvas.drawPath(_poly([44, 52, 50, 40, 56, 52]), _f(0xFF1E4D55));
        canvas.drawPath(_poly([108, 52, 113, 42, 118, 52]), _f(0xFF1E4D55));
      case GameId.sleuth:
        // A lighthouse on a rocky islet; its lamp glows.
        canvas.drawPath(
          _poly([50, 52, 58, 44, 100, 44, 108, 52]),
          _f(0xFF8C7B87),
        );
        canvas.drawPath(
          _poly([68, 46, 72, 20, 82, 20, 86, 46]),
          _f(0xFFFFFFFF),
        );
        canvas.drawPath(
          _poly([69.4, 38, 70.3, 30, 83.7, 30, 84.6, 38]),
          _f(0xFFD81B60),
        );
        canvas.drawRect(const Rect.fromLTWH(72, 12, 10, 8), _f(0xFFFFE08A));
        canvas.drawPath(_poly([70, 12, 77, 5, 84, 12]), _f(0xFF9C1346));
        final lamp = (sin(v * 2) + 1) / 2;
        canvas.drawCircle(
          const Offset(77, 16),
          9 + 4 * lamp,
          Paint()
            ..color = const Color(0xFFFFE08A)
                .withValues(alpha: .18 + .25 * lamp),
        );
      case GameId.bridges:
        // Two islets joined by a little wooden bridge.
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(48, 48), width: 38, height: 14),
          _f(0xFF5FC9AE),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(106, 46), width: 38, height: 14),
          _f(0xFF5FC9AE),
        );
        canvas.drawRect(const Rect.fromLTWH(64, 45, 26, 5), _f(0xFFB8803F));
        for (var x = 67.0; x < 90; x += 5) {
          canvas.drawLine(
            Offset(x, 45),
            Offset(x, 50),
            Paint()
              ..color = const Color(0xFF8A5A2B)
              ..strokeWidth = 1,
          );
        }
        canvas.drawLine(
          const Offset(64, 43),
          const Offset(90, 43),
          Paint()
            ..color = const Color(0xFF8A5A2B)
            ..strokeWidth = 1.6,
        );
        _palm(canvas, 44, 48);
        _palm(canvas, 108, 46);
    }
    canvas.restore();

    switch (game) {
      case GameId.thread:
        final k = t.value;
        canvas.drawCircle(
          Offset(76 + 4 * k, 12 - k * 10),
          3 + 2 * k,
          Paint()..color = Colors.white.withValues(alpha: (1 - k) * .8),
        );
        _palm(canvas, 120, 52);
      case GameId.quilt:
        canvas.drawRect(const Rect.fromLTWH(112, 26, 6, 24), _f(0xFFF4F7FB));
        canvas.drawPath(_poly([110, 26, 115, 20, 120, 26]), _f(0xFFB93C14));
        final hub = const Offset(115, 25);
        final blade = Paint()
          ..color = const Color(0xFF13213C)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          final a = v + i * pi / 2;
          canvas.drawLine(hub, hub + Offset(cos(a), sin(a)) * 12, blade);
        }
      case GameId.twist:
        final a = (sin(v * 2) + 1) / 2;
        _sparkle(
          canvas,
          const Offset(122, 18),
          3 + a * 3,
          const Color(0xFFFFC233).withValues(alpha: .4 + a * .6),
        );
        _sparkle(
          canvas,
          const Offset(40, 28),
          2 + (1 - a) * 2,
          Colors.white.withValues(alpha: .3 + (1 - a) * .7),
        );
      case GameId.sudoku:
        final flake = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.save();
        canvas.translate(128, 14);
        canvas.rotate(v / 3);
        for (var i = 0; i < 3; i++) {
          final a = i * pi / 3;
          canvas.drawLine(
            Offset(cos(a), sin(a)) * -6,
            Offset(cos(a), sin(a)) * 6,
            flake,
          );
        }
        canvas.restore();
      case GameId.sleuth:
        // A buoy bobbing by the rocks.
        final bb = sin(v * 2) * 1.2;
        canvas.drawCircle(
          Offset(120, 56 + bb),
          5,
          Paint()
            ..color = const Color(0xFFE8365D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(120, 56 + bb), radius: 5),
          .4,
          1.2,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case GameId.bridges:
        // A lily pad and a sparkle on the water.
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(28, 58), width: 16, height: 6),
          _f(0xFF4FB87A),
        );
        final sp = (sin(v * 2) + 1) / 2;
        _sparkle(
          canvas,
          const Offset(124, 20),
          2.5 + sp * 3,
          Colors.white.withValues(alpha: .3 + sp * .7),
        );
    }
    final trail = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 38.0; x < 116; x += 7) {
      final y = 58 - 12 * sin((x - 36) / 80 * pi);
      canvas.drawCircle(Offset(x, y), 1.1, trail);
    }
    canvas.restore();
  }

  void _palm(Canvas c, double x, double y) {
    final trunk = Paint()
      ..color = const Color(0xFF8A5A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 2, y - 8, x + 4, y - 16),
      trunk,
    );
    final leaf = Paint()
      ..color = const Color(0xFF2E9E5B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final top = Offset(x + 4, y - 16);
    for (final q in const [
      (-8.0, -1.0, -11.0, 5.0),
      (8.0, -4.0, 12.0, 2.0),
      (-2.0, -7.0, -8.0, -8.0),
      (4.0, -7.0, 10.0, -6.0),
    ]) {
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..relativeQuadraticBezierTo(q.$1, q.$2, q.$3, q.$4),
        leaf,
      );
    }
  }

  void _sparkle(Canvas c, Offset at, double r, Color col) {
    final p = Path()
      ..moveTo(at.dx, at.dy - r)
      ..lineTo(at.dx + r * .3, at.dy - r * .3)
      ..lineTo(at.dx + r, at.dy)
      ..lineTo(at.dx + r * .3, at.dy + r * .3)
      ..lineTo(at.dx, at.dy + r)
      ..lineTo(at.dx - r * .3, at.dy + r * .3)
      ..lineTo(at.dx - r, at.dy)
      ..lineTo(at.dx - r * .3, at.dy - r * .3)
      ..close();
    c.drawPath(p, Paint()..color = col);
  }

  @override
  bool shouldRepaint(_MiniPainter old) =>
      old.game != game || old.night != night;
}
