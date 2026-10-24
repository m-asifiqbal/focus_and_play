// Small illustrations used across screens: star, Pip the puffin, player badges,
// confetti and the hexagon achievement badge.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/achievements.dart';
import '../theme/mi_colors.dart';

export 'pip.dart';

/// Five-point star (filled sun gold, or an empty grey outline).
class StarShape extends StatelessWidget {
  const StarShape({
    super.key,
    required this.filled,
    this.size = 16,
    this.fill,
    this.stroke,
  });
  final bool filled;
  final double size;
  final Color? fill;
  final Color? stroke;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(
        fill: filled
            ? (fill ?? c.sun)
            : (c.isNight ? const Color(0xFF2A3A57) : const Color(0xFFE6EBF1)),
        stroke: filled
            ? (stroke ?? const Color(0xFF8A6100))
            : (c.isNight ? const Color(0xFF6F82A0) : const Color(0xFF8C9BB3)),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.fill, required this.stroke});
  final Color fill, stroke;

  static Path starPath(Size s) {
    final p = Path();
    final cx = s.width / 2, cy = s.height / 2 + s.height * .03;
    final r1 = s.width * .48, r2 = s.width * .22;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? r1 : r2;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cx + r * cos(a), cy + r * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = starPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = max(1, size.width * .06),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// The six player badges chosen in onboarding.
class PlayerBadge {
  const PlayerBadge(this.name, this.icon, this.color, this.onColor);
  final String name;
  final IconData icon;
  final Color color;
  final Color onColor;

  static const all = [
    PlayerBadge(
      'Compass',
      Icons.explore_rounded,
      Color(0xFF0A7C70),
      Colors.white,
    ),
    PlayerBadge('Wave', Icons.waves_rounded, Color(0xFFF0582A), Colors.white),
    PlayerBadge('Palm', Icons.park_rounded, Color(0xFF1F9D55), Colors.white),
    PlayerBadge(
      'Crystal',
      Icons.diamond_rounded,
      Color(0xFF8A4FD8),
      Colors.white,
    ),
    PlayerBadge(
      'Snowflake',
      Icons.ac_unit_rounded,
      Color(0xFF1E9BDC),
      Color(0xFF0D1626),
    ),
    PlayerBadge(
      'Star',
      Icons.star_rounded,
      Color(0xFFFFC233),
      Color(0xFF13213C),
    ),
  ];

  static PlayerBadge of(int i) => all[i.clamp(0, all.length - 1)];
}

/// Round avatar showing a player badge.
class BadgeAvatar extends StatelessWidget {
  const BadgeAvatar({
    super.key,
    required this.badge,
    this.size = 44,
    this.ring = false,
  });
  final int badge;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final b = PlayerBadge.of(badge);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: b.color,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: context.mi.ink, width: 3) : null,
      ),
      child: Icon(b.icon, color: b.onColor, size: size * .55),
    );
  }
}

/// Hexagon achievement badge, coloured by kind, greyed with a lock when not earned.
class HexBadge extends StatelessWidget {
  const HexBadge({
    super.key,
    required this.kind,
    required this.unlocked,
    this.size = 52,
  });
  final BadgeKind kind;
  final bool unlocked;
  final double size;

  static (Color, IconData, Color) look(BadgeKind k) => switch (k) {
    BadgeKind.thread => (
      const Color(0xFFF0582A),
      Icons.gesture_rounded,
      Colors.white,
    ),
    BadgeKind.quilt => (
      const Color(0xFF1F9D55),
      Icons.grid_view_rounded,
      Colors.white,
    ),
    BadgeKind.twist => (
      const Color(0xFF8A4FD8),
      Icons.abc_rounded,
      Colors.white,
    ),
    BadgeKind.sudoku => (
      const Color(0xFF1E9BDC),
      Icons.ac_unit_rounded,
      const Color(0xFF0D1626),
    ),
    BadgeKind.sleuth => (
      const Color(0xFFD81B60),
      Icons.search_rounded,
      Colors.white,
    ),
    BadgeKind.bridges => (
      const Color(0xFF14B8A6),
      Icons.timeline_rounded,
      const Color(0xFF0D1626),
    ),
    BadgeKind.streak => (
      const Color(0xFF0A7C70),
      Icons.local_fire_department_rounded,
      const Color(0xFFFFC233),
    ),
    BadgeKind.star => (
      const Color(0xFFFFC233),
      Icons.star_rounded,
      const Color(0xFF13213C),
    ),
    BadgeKind.moon => (
      const Color(0xFF13213C),
      Icons.nightlight_round,
      const Color(0xFFFFC233),
    ),
    BadgeKind.sun => (
      const Color(0xFFFFB020),
      Icons.wb_sunny_rounded,
      const Color(0xFF13213C),
    ),
    BadgeKind.hint => (
      const Color(0xFFFFC233),
      Icons.lightbulb_rounded,
      const Color(0xFF13213C),
    ),
    BadgeKind.crown => (
      const Color(0xFF13213C),
      Icons.workspace_premium_rounded,
      const Color(0xFFFFC233),
    ),
    BadgeKind.heart => (
      const Color(0xFFE8365D),
      Icons.favorite_rounded,
      Colors.white,
    ),
    BadgeKind.island => (
      const Color(0xFF0A7C70),
      Icons.sailing_rounded,
      Colors.white,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (color, icon, on) = look(kind);
    final c = context.mi;
    final bg = unlocked
        ? color
        : (c.isNight ? const Color(0xFF2A3A57) : const Color(0xFFE6EDF4));
    return SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(
        painter: _HexPainter(bg),
        child: Center(
          child: Icon(
            unlocked ? icon : Icons.lock_rounded,
            size: size * .44,
            color: unlocked ? on : const Color(0xFF5A6A85),
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height * .25)
      ..lineTo(s.width, s.height * .75)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(0, s.height * .75)
      ..lineTo(0, s.height * .25)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}

/// Falling confetti over its area. Draws nothing when animations are off.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 40, this.loop = true});
  final int count;
  final bool loop;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  final _rng = Random(4);
  late final List<_Bit> _bits = List.generate(widget.count, (i) => _Bit(_rng));

  @override
  void initState() {
    super.initState();
    widget.loop ? _c.repeat() : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(_c, _bits),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Bit {
  _Bit(Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble(),
      speed = .7 + r.nextDouble() * .6,
      spin = (r.nextDouble() - .5) * 12,
      w = 6 + r.nextDouble() * 5,
      h = 8 + r.nextDouble() * 6,
      color = const [
        Color(0xFFFFC233),
        Color(0xFF1E9BDC),
        Color(0xFF1F9D55),
        Color(0xFFF0582A),
        Color(0xFF8A4FD8),
        Color(0xFFE8365D),
        Colors.white,
      ][r.nextInt(7)];
  final double x, delay, speed, spin, w, h;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.bits) : super(repaint: anim);
  final Animation<double> anim;
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final t = (anim.value * b.speed + b.delay) % 1.0;
      final y = -20 + t * (size.height + 40);
      final x = b.x * size.width + sin(t * 8 + b.delay * 6) * 16;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * b.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: b.w, height: b.h),
          const Radius.circular(2),
        ),
        Paint()..color = b.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
