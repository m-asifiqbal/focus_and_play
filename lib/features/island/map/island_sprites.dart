// Scenery sprites for the island map, drawn straight onto a Canvas.
// Each sprite is anchored at its base point (where it touches the ground).

import 'dart:math';
import 'dart:ui';

import 'island_palette.dart';

Paint _fill(int c) => Paint()..color = Color(c);
Paint _stroke(int c, double w) => Paint()
  ..color = Color(c)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
final _shadow = Paint()..color = const Color(0x22000000);

void _shadowAt(Canvas c, double x, double y, double rx, double ry) => c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), _shadow);

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

void drawDeco(Canvas c, Deco d, double x, double y, double s, int v) {
  switch (d) {
    case Deco.palm:
      _shadowAt(c, x + 4 * s, y + 2, 12 * s, 3.5 * s);
      c.drawPath(Path()..moveTo(x, y)..quadraticBezierTo(x + 3 * s, y - 14 * s, x + 6 * s, y - 28 * s), _stroke(0xFF8A5A3A, 4 * s));
      final top = Offset(x + 6 * s, y - 28 * s);
      final leaf = _stroke(0xFF2E9E5B, 5 * s);
      for (final q in const [(-12.0, -2.0, -17.0, 7.0), (12.0, -6.0, 18.0, 3.0), (-3.0, -11.0, -12.0, -13.0), (6.0, -11.0, 15.0, -10.0)]) {
        c.drawPath(Path()..moveTo(top.dx, top.dy)..relativeQuadraticBezierTo(q.$1 * s, q.$2 * s, q.$3 * s, q.$4 * s), leaf);
      }
      c.drawCircle(top, 2.6 * s, _fill(0xFF6B3F22));
    case Deco.bush:
      _shadowAt(c, x, y + 5 * s, 15 * s, 4 * s);
      final col = v.isEven ? 0xFF5FB070 : 0xFF4FA562;
      c.drawCircle(Offset(x - 7 * s, y), 7 * s, _fill(col));
      c.drawCircle(Offset(x + 7 * s, y), 7 * s, _fill(col));
      c.drawCircle(Offset(x, y - 6 * s), 8 * s, _fill(col));
      c.drawCircle(Offset(x - 2 * s, y - 9 * s), 3 * s, _fill(0xFF8ED69B));
    case Deco.flower:
      final col = const [0xFFF7B6C2, 0xFFFFD66B, 0xFFFFFFFF, 0xFFC9B8F5][v];
      for (final o in const [Offset(0, 0), Offset(8, 4), Offset(-7, 5)]) {
        c.drawCircle(Offset(x + o.dx * s, y + o.dy * s), 2.8 * s, _fill(col));
        c.drawCircle(Offset(x + o.dx * s, y + o.dy * s), 1.1 * s, _fill(0xFFFFF3B0));
      }
    case Deco.shell:
      final col = v.isEven ? 0xFFF7B6C2 : 0xFFFFC2A1;
      c.drawCircle(Offset(x, y), 3.6 * s, _fill(col));
      c.drawLine(Offset(x - 3 * s, y), Offset(x + 3 * s, y), _stroke(0xFFFFFFFF, 1));
    case Deco.pool:
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 30 * s, height: 14 * s), _fill(0xFFC9B184));
      c.drawOval(Rect.fromCenter(center: Offset(x, y - 1), width: 24 * s, height: 10 * s), _fill(0xFF7FCBE8));
      c.drawCircle(Offset(x + 4 * s, y - 2), 1.6 * s, _fill(0xFFF0582A));
    case Deco.rock:
    case Deco.darkRock:
    case Deco.violetRock:
      final (body, hi) = switch (d) {
        Deco.darkRock => (0xFF4E413C, 0xFF6E5D57),
        Deco.violetRock => (0xFF6B5A9A, 0xFF9586C2),
        _ => (0xFF7E6A5D, 0xFFA48D7C),
      };
      _shadowAt(c, x, y + 4 * s, 13 * s, 4 * s);
      c.drawPath(_poly([x - 12 * s, y + 3 * s, x - 9 * s, y - 7 * s, x - s, y - 11 * s, x + 9 * s, y - 6 * s, x + 12 * s, y + 3 * s]), _fill(body));
      c.drawPath(_poly([x - 9 * s, y - 7 * s, x - s, y - 11 * s, x + 3 * s, y - 4 * s, x - 5 * s, y - 2 * s]), _fill(hi));
    case Deco.hexCluster:
      for (final h in const [(-13.0, 6.0, 11.0), (9.0, 9.0, 12.0), (-2.0, -6.0, 12.0)]) {
        _hex(c, x + h.$1 * s, y + h.$2 * s, h.$3 * s);
      }
    case Deco.crack:
    case Deco.iceCrack:
      c.drawPath(
        Path()..moveTo(x - 14 * s, y)..relativeLineTo(8 * s, -5 * s)..relativeLineTo(5 * s, 6 * s)..relativeLineTo(9 * s, -4 * s)..relativeLineTo(6 * s, 5 * s),
        _stroke(d == Deco.iceCrack ? 0xFF6F9CC4 : 0xFFF0582A, 2.5 * s),
      );
    case Deco.vent:
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 14, height: 7), _fill(0xFF5A4A42));
      c.drawCircle(Offset(x, y - 9), 4, _fill(0xCCFFFFFF));
      c.drawCircle(Offset(x + 3, y - 16), 3, _fill(0x99FFFFFF));
    case Deco.lavaPool:
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 32 * s, height: 16 * s), _fill(0xFF7A4A38));
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 26 * s, height: 12 * s), _fill(0xFFF0582A));
      c.drawOval(Rect.fromCenter(center: Offset(x - 2 * s, y - s), width: 12 * s, height: 5 * s), _fill(0xFFFFC233));
    case Deco.field:
      final cols = const [0xFFB6E7C6, 0xFFFFD68A, 0xFF7FD39B, 0xFFF7CFA0];
      final r = Rect.fromCenter(center: Offset(x, y - 6 * s), width: 34 * s, height: 22 * s);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(4 * s)), _fill(cols[v]));
      final dash = _stroke(0xFFFFFFFF, 1.4);
      for (var i = 0; i < 6; i++) {
        c.drawLine(Offset(r.left + 3 + i * 5.2 * s, r.top + 3), Offset(r.left + 5 + i * 5.2 * s, r.top + 3), dash);
        c.drawLine(Offset(r.left + 3 + i * 5.2 * s, r.bottom - 3), Offset(r.left + 5 + i * 5.2 * s, r.bottom - 3), dash);
      }
    case Deco.hay:
      _shadowAt(c, x, y + 3, 11 * s, 3 * s);
      c.drawCircle(Offset(x, y - 7 * s), 9 * s, _fill(0xFFE9C46A));
      c.drawCircle(Offset(x, y - 7 * s), 5 * s, _stroke(0xFFC99A3A, 1.6));
    case Deco.windmill:
      _shadowAt(c, x, y + 2, 12 * s, 3 * s);
      c.drawPath(_poly([x - 6 * s, y, x - 4 * s, y - 30 * s, x + 4 * s, y - 30 * s, x + 6 * s, y]), _fill(0xFFF4F7FB));
      c.drawPath(_poly([x - 7 * s, y - 29 * s, x, y - 37 * s, x + 7 * s, y - 29 * s]), _fill(0xFFB93C14));
      final hub = Offset(x, y - 31 * s);
      final blade = _stroke(0xFF13213C, 2.4 * s);
      for (var i = 0; i < 4; i++) {
        final a = i * pi / 2 + v * .4;
        c.drawLine(hub, hub + Offset(cos(a), sin(a)) * 14 * s, blade);
      }
    case Deco.sheep:
      _shadowAt(c, x, y + 3, 10 * s, 3 * s);
      for (final o in const [Offset(-4, -6), Offset(3, -7), Offset(0, -10), Offset(-1, -4)]) {
        c.drawCircle(Offset(x + o.dx * s, y + o.dy * s), 5 * s, _fill(0xFFFFFFFF));
      }
      c.drawCircle(Offset(x + 8 * s, y - 8 * s), 3.5 * s, _fill(0xFF3B3B4F));
    case Deco.fruitTree:
      _shadowAt(c, x, y + 3, 14 * s, 4 * s);
      c.drawRect(Rect.fromLTWH(x - 2.5 * s, y - 12 * s, 5 * s, 12 * s), _fill(0xFF8A5A3A));
      c.drawCircle(Offset(x, y - 20 * s), 12 * s, _fill(0xFF3F9C55));
      c.drawCircle(Offset(x - 5 * s, y - 24 * s), 2.4 * s, _fill(v.isEven ? 0xFFE8365D : 0xFFFFB020));
      c.drawCircle(Offset(x + 5 * s, y - 18 * s), 2.4 * s, _fill(v.isEven ? 0xFFE8365D : 0xFFFFB020));
    case Deco.crystalSmall:
      _crystal(c, x, y, 7 * s, 20 * s, 0xFFB48AF0);
      _crystal(c, x + 7 * s, y + 2, 5 * s, 13 * s, 0xFF8A4FD8);
    case Deco.crystalBig:
      _shadowAt(c, x, y + 3, 16 * s, 4 * s);
      _crystal(c, x - 9 * s, y, 7 * s, 22 * s, 0xFF8A4FD8);
      _crystal(c, x + 2 * s, y, 9 * s, 34 * s, 0xFFB48AF0);
      _crystal(c, x + 12 * s, y + 1, 6 * s, 16 * s, 0xFF6B35C4);
    case Deco.mushroom:
      c.drawRect(Rect.fromLTWH(x - 2 * s, y - 8 * s, 4 * s, 8 * s), _fill(0xFFF4F7FB));
      c.drawPath(Path()..addArc(Rect.fromCenter(center: Offset(x, y - 8 * s), width: 18 * s, height: 14 * s), pi, pi), _fill(v.isEven ? 0xFF8A4FD8 : 0xFF1E9BDC));
      c.drawCircle(Offset(x - 3 * s, y - 11 * s), 1.6 * s, _fill(0xFFFFFFFF));
    case Deco.pine:
      _shadowAt(c, x, y + 2 * s, 11 * s, 3.5 * s);
      c.drawRect(Rect.fromLTWH(x - 2 * s, y - 6 * s, 4 * s, 8 * s), _fill(0xFF6B4B37));
      c.drawPath(_poly([x, y - 34 * s, x + 12 * s, y - 6 * s, x - 12 * s, y - 6 * s]), _fill(0xFF24614F));
      c.drawPath(_poly([x, y - 34 * s, x + 5 * s, y - 22 * s, x + s, y - 24 * s, x - 3 * s, y - 21 * s, x - 5 * s, y - 23 * s]), _fill(0xFFEAF2FA));
    case Deco.drift:
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 32 * s, height: 10 * s), _fill(0xFFF4F8FC));
    case Deco.ice:
      c.drawPath(_poly([x - 12 * s, y, x - 8 * s, y - 10 * s, x + 4 * s, y - 13 * s, x + 12 * s, y - 4 * s, x + 8 * s, y + 2 * s]), _fill(0xFFDDF0FC));
      c.drawPath(_poly([x - 8 * s, y - 10 * s, x + 4 * s, y - 13 * s, x, y - 5 * s]), _fill(0xFFFFFFFF));
    case Deco.lantern:
      c.drawRect(Rect.fromLTWH(x - 1.2, y - 12, 2.4, 12), _fill(0xFF3B2A22));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 3.5, y - 19, 7, 8), const Radius.circular(2)), _fill(0xFFFFD66B));
  }
}

void _hex(Canvas c, double x, double y, double r) {
  Path ring(double cy) => _poly([for (var a = 0; a < 6; a++) ...[x + r * cos(a * pi / 3), cy + r * .62 * sin(a * pi / 3)]]);
  c.drawPath(ring(y + r * .55), _fill(0xFF8E7466));
  c.drawRect(Rect.fromLTWH(x - r, y, r * 2, r * .55), _fill(0xFF8E7466));
  c.drawPath(ring(y), _fill(0xFFCDB6A2));
}

void _crystal(Canvas c, double x, double y, double w, double h, int col) {
  c.drawPath(_poly([x - w / 2, y, x - w / 2, y - h * .75, x, y - h, x + w / 2, y - h * .75, x + w / 2, y]), _fill(col));
  c.drawPath(_poly([x, y, x, y - h, x + w / 2, y - h * .75, x + w / 2, y]), _fill(0x33FFFFFF));
}

/// Little wooden bridge across a river, rotated along the road.
void drawBridge(Canvas c, Offset at, double angle) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  const l = 48.0, w = 36.0;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: l, height: w), const Radius.circular(4)), _fill(0xFF8A5A3A));
  final plank = _stroke(0x995E3B24, 1.6);
  for (var d = -16.0; d <= 16; d += 8) {
    c.drawLine(Offset(d, -w / 2 + 2), Offset(d, w / 2 - 2), plank);
  }
  final rail = _fill(0xFF5E3B24);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-l / 2 - 2, -w / 2 - 3, l + 4, 4), const Radius.circular(2)), rail);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-l / 2 - 2, w / 2 - 1, l + 4, 4), const Radius.circular(2)), rail);
  c.restore();
}

/// River body for its kind.
void drawRiver(Canvas c, Path p, RiverKind k) {
  final (bank, body, core) = switch (k) {
    RiverKind.lava => (0xFF7A4A38, 0xFFF0582A, 0xFFFFC233),
    RiverKind.glow => (0xFF6B5A9A, 0xFFB48AF0, 0xFFF3EBFF),
    RiverKind.ice => (0xFF7FA6C8, 0xFFB5DDF5, 0xFFFFFFFF),
    RiverKind.stream => (0xFF5FA8C8, 0xFF86CFEA, 0xFFE4F6FD),
  };
  c.drawPath(p, _stroke(bank, 26));
  c.drawPath(p, _stroke(body, 18));
  c.drawPath(p, _stroke(core, k == RiverKind.lava ? 4 : 2.5));
}

/// Dock + sailing boat at the start of the road.
void drawDock(Canvas c, Offset base) {
  final dock = Rect.fromLTWH(base.dx - 22, base.dy - 10, 44, 64);
  c.drawRRect(RRect.fromRectAndRadius(dock, const Radius.circular(4)), _fill(0xFF8A5A3A));
  for (var y = dock.top + 8; y < dock.bottom; y += 12) {
    c.drawLine(Offset(dock.left + 2, y), Offset(dock.right - 2, y), _stroke(0xFF5E3B24, 1.6));
  }
  final bx = base.dx - 58, by = base.dy + 48;
  c.drawPath(_poly([bx - 26, by, bx + 26, by, bx + 18, by + 14, bx - 18, by + 14]), _fill(0xFFB93C14));
  c.drawLine(Offset(bx, by), Offset(bx, by - 34), _stroke(0xFF13213C, 2.5));
  c.drawPath(_poly([bx + 1, by - 32, bx + 20, by - 4, bx + 1, by - 4]), _fill(0xFFFFFFFF));
}

/// The landmark at the top of the island.
void drawSummit(Canvas c, Summit s, Offset at) {
  switch (s) {
    case Summit.crater:
      c.drawOval(Rect.fromCenter(center: at, width: 156, height: 88), _fill(0xFF4E413C));
      c.drawOval(Rect.fromCenter(center: at.translate(0, -6), width: 124, height: 64), _fill(0xFF3A2F2B));
      c.drawOval(Rect.fromCenter(center: at.translate(0, -4), width: 100, height: 48), _fill(0xFFF0582A));
      c.drawOval(Rect.fromCenter(center: at.translate(-10, -8), width: 44, height: 16), _fill(0xFFFFC233));
    case Summit.bigTree:
      _shadowAt(c, at.dx, at.dy + 24, 60, 14);
      c.drawRect(Rect.fromLTWH(at.dx - 9, at.dy - 20, 18, 46), _fill(0xFF8A5A3A));
      for (final o in const [Offset(-30, -34), Offset(28, -36), Offset(0, -56), Offset(-12, -20), Offset(16, -18)]) {
        c.drawCircle(at + o, 28, _fill(0xFF3F9C55));
      }
      for (final o in const [Offset(-26, -44), Offset(20, -50), Offset(4, -64), Offset(-4, -26), Offset(26, -24)]) {
        c.drawCircle(at + o, 4, _fill(0xFFE8365D));
      }
    case Summit.spire:
      _shadowAt(c, at.dx, at.dy + 20, 60, 12);
      _crystal(c, at.dx - 34, at.dy + 18, 22, 60, 0xFF8A4FD8);
      _crystal(c, at.dx, at.dy + 20, 30, 110, 0xFFB48AF0);
      _crystal(c, at.dx + 32, at.dy + 18, 20, 52, 0xFF6B35C4);
    case Summit.peak:
      c.drawPath(_poly([at.dx - 90, at.dy + 30, at.dx - 30, at.dy - 60, at.dx, at.dy - 20, at.dx + 30, at.dy - 70, at.dx + 90, at.dy + 30]), _fill(0xFF1E9BDC));
      c.drawPath(_poly([at.dx - 30, at.dy - 60, at.dx - 16, at.dy - 38, at.dx - 26, at.dy - 42, at.dx - 34, at.dy - 34, at.dx - 42, at.dy - 42]), _fill(0xFFFFFFFF));
      c.drawPath(_poly([at.dx + 30, at.dy - 70, at.dx + 44, at.dy - 48, at.dx + 34, at.dy - 52, at.dx + 26, at.dy - 44, at.dx + 18, at.dy - 52]), _fill(0xFFFFFFFF));
  }
}
