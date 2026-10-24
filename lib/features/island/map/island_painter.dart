// Painters for the island map.
//
// MapTilePainter draws one horizontal slice of the static world (sea, shore,
// zones, rivers, scenery, road) and is wrapped in a RepaintBoundary, so each
// slice is rasterised once. AmbientPainter draws only what is on screen and
// repaints every frame: shimmering waves, glowing lava, steam, sparkles, snow,
// drifting clouds and birds.

import 'dart:math';

import 'package:flutter/material.dart';

import 'island_layout.dart';
import 'island_palette.dart';
import 'island_sprites.dart';

/// Paths built once per layout (land outline, zone shapes, road).
class MapGeometry {
  MapGeometry(this.layout) {
    final l = layout;
    Path land(double inset) {
      final p = Path();
      final ys = [for (var y = 60.0; y <= l.height - 20; y += 24) y];
      p.moveTo(l.leftEdge(ys.first) + inset, ys.first + inset);
      for (final y in ys) {
        p.lineTo(l.leftEdge(y) + inset, y);
      }
      p.quadraticBezierTo(l.width / 2, l.height + 30 - inset * 2, l.rightEdge(ys.last) - inset, ys.last);
      for (final y in ys.reversed) {
        p.lineTo(l.rightEdge(y) - inset, y);
      }
      p.quadraticBezierTo(l.width / 2, 10 + inset * 2, l.leftEdge(ys.first) + inset, ys.first + inset);
      return p..close();
    }

    landOuter = land(0);
    landInner = land(13);
    road = Path()..moveTo(l.road.first.a.dx, l.road.first.a.dy);
    for (final s in l.road) {
      road.cubicTo(s.c1.dx, s.c1.dy, s.c2.dx, s.c2.dy, s.b.dx, s.b.dy);
    }
  }

  final IslandLayout layout;
  late final Path landOuter;
  late final Path landInner;
  late final Path road;

  /// Road from the dock up to [level]'s pad (the lit, finished part).
  Path doneRoad(int level) {
    final p = Path()..moveTo(layout.road.first.a.dx, layout.road.first.a.dy);
    final end = IslandLayout.segEndingAt(level.clamp(1, layout.nodes.length));
    for (var i = 0; i <= end && i < layout.road.length; i++) {
      final s = layout.road[i];
      p.cubicTo(s.c1.dx, s.c1.dy, s.c2.dx, s.c2.dy, s.b.dx, s.b.dy);
    }
    return p;
  }

  Path zoneBoundary(double y, double wob) => Path()
    ..moveTo(-10, y)
    ..cubicTo(layout.width * .22, y - 20 + wob, layout.width * .42, y + 22, layout.width * .62, y - 6)
    ..cubicTo(layout.width * .78, y - 22, layout.width * .9, y + 12, layout.width + 10, y - 4);
}

Paint _p(Color c) => Paint()..color = c;
Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class MapTilePainter extends CustomPainter {
  MapTilePainter({required this.geo, required this.palette, required this.top, required this.height, required this.night, required this.current});
  final MapGeometry geo;
  final IslandPalette palette;
  final double top;
  final double height;
  final bool night;

  /// Frontier level: the road is lit up to here.
  final int current;

  @override
  void paint(Canvas canvas, Size size) {
    final l = geo.layout;
    final y0 = top, y1 = top + height;
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -top);

    canvas.drawRect(Rect.fromLTWH(0, y0, l.width, height), _p(night ? IslandPalette.seaNight : IslandPalette.sea));
    final wave = _s(Colors.white.withValues(alpha: night ? .18 : .55), 2);
    for (var y = (y0 ~/ 90) * 90.0; y < y1; y += 90) {
      final x = ((y ~/ 90) % 2 == 0) ? 6.0 : l.width - 26;
      canvas.drawPath(Path()..moveTo(x, y)..relativeQuadraticBezierTo(5, -4, 10, 0)..relativeQuadraticBezierTo(5, 4, 10, 0), wave);
    }

    canvas.drawPath(geo.landOuter, _p(palette.shore));
    canvas.drawPath(geo.landOuter, _s(Colors.white.withValues(alpha: .85), 3));

    canvas.save();
    canvas.clipPath(geo.landInner);
    final b = l.zoneBounds;
    final zoneTops = [b[0], b[1], b[2], -100.0];
    final zoneBottoms = [l.height + 100, b[0], b[1], b[2]];
    for (var z = 0; z < 4; z++) {
      if (zoneBottoms[z] < y0 - 40 || zoneTops[z] > y1 + 40) continue;
      final path = Path()..addRect(Rect.fromLTRB(-10, zoneTops[z], l.width + 10, zoneBottoms[z] + 30));
      canvas.drawPath(path, _p(palette.zones[z].ground));
    }
    for (var z = 0; z < 3; z++) {
      final y = b[z];
      if (y < y0 - 60 || y > y1 + 60) continue;
      final above = palette.zones[z + 1];
      final edge = geo.zoneBoundary(y, z.isEven ? 6 : -8);
      final fillAbove = Path.from(edge)
        ..lineTo(l.width + 10, y - 200)
        ..lineTo(-10, y - 200)
        ..close();
      canvas.drawPath(fillAbove, _p(above.ground));
      canvas.drawPath(edge, _s(palette.zones[z].edge, 8));
    }

    for (final r in l.rivers) {
      if ((r.crossing.dy - y0) < -80 || (r.crossing.dy - y1) > 80) continue;
      drawRiver(canvas, r.path, r.kind);
    }
    for (final d in l.decos) {
      if (d.pos.dy < y0 - 60 || d.pos.dy > y1 + 60) continue;
      drawDeco(canvas, d.kind, d.pos.dx, d.pos.dy, d.scale, d.variant);
    }
    if (y0 < 420) drawSummit(canvas, palette.summit, Offset(l.width / 2, 230));
    canvas.restore();

    final edge = palette.zones[l.zoneAt((y0 + y1) / 2)].edge;
    canvas.drawPath(geo.road, _s(Color.lerp(edge, const Color(0xFF5A4A42), .45)!, 30));
    canvas.drawPath(geo.road, _s(IslandPalette.road, 22));
    final dot = _p(Colors.white);
    for (var i = 0; i < l.roadSamples.length; i += 2) {
      final s = l.roadSamples[i];
      if (s.dy < y0 - 10 || s.dy > y1 + 10) continue;
      canvas.drawCircle(s, 1.6, dot);
    }
    for (final r in l.rivers) {
      if ((r.crossing.dy - y0) < -60 || (r.crossing.dy - y1) > 60) continue;
      drawBridge(canvas, r.crossing, r.angle);
    }
    if (y1 > l.height - 300) drawDock(canvas, l.road.first.a);

    if (night) {
      canvas.drawRect(Rect.fromLTWH(0, y0, l.width, height), _p(const Color(0xFF0D1626).withValues(alpha: .42)));
      for (final d in l.decos) {
        if (d.kind != Deco.lantern || d.pos.dy < y0 - 30 || d.pos.dy > y1 + 30) continue;
        canvas.drawCircle(d.pos.translate(0, -15), 14, _p(const Color(0xFFFFC233).withValues(alpha: .35)));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(d.pos.dx - 3.5, d.pos.dy - 19, 7, 8), const Radius.circular(2)), _p(const Color(0xFFFFE08A)));
      }
    }
    canvas.drawPath(geo.doneRoad(current), _s(palette.accent, 9));
  }

  @override
  bool shouldRepaint(MapTilePainter old) => old.current != current || old.night != night || old.geo != geo;
}

/// Moving details for the visible part of the map only.
class AmbientPainter extends CustomPainter {
  AmbientPainter({required this.layout, required this.palette, required this.top, required this.time, required this.night, required this.frost}) : super(repaint: time);
  final IslandLayout layout;
  final IslandPalette palette;
  final double top;
  final Animation<double> time;
  final bool night;
  final bool frost;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value * 20; // seconds-ish, loops every 20 s
    final y0 = top, y1 = top + size.height;
    canvas.translate(0, -top);

    // Shimmering waves along the sea margins.
    for (var y = (y0 ~/ 70) * 70.0; y < y1; y += 70) {
      final k = (y ~/ 70) % 3;
      final x = k == 0 ? 10.0 : (k == 1 ? layout.width - 30 : 18.0);
      final a = (sin(t * 1.6 + y / 50) + 1) / 2;
      canvas.drawPath(
        Path()..moveTo(x + a * 4, y + 30)..relativeQuadraticBezierTo(5, -4, 10, 0)..relativeQuadraticBezierTo(5, 4, 10, 0),
        _s(Colors.white.withValues(alpha: (night ? .1 : .25) + a * (night ? .25 : .55)), 2),
      );
    }

    for (final d in layout.decos) {
      if (d.pos.dy < y0 - 40 || d.pos.dy > y1 + 40) continue;
      final ph = d.pos.dx * .05 + d.pos.dy * .01;
      switch (d.kind) {
        case Deco.lavaPool:
          final a = (sin(t * 2 + ph) + 1) / 2;
          canvas.drawOval(Rect.fromCenter(center: d.pos, width: 34 * d.scale, height: 18 * d.scale), _p(const Color(0xFFFFC233).withValues(alpha: .15 + a * .3)));
        case Deco.vent:
          final k = (t * .45 + ph) % 1.0;
          canvas.drawCircle(d.pos.translate(0, -8 - k * 26), 4 + k * 5, _p(Colors.white.withValues(alpha: (1 - k) * .7)));
        case Deco.crystalSmall:
        case Deco.crystalBig:
          final a = (sin(t * 2.4 + ph * 3) + 1) / 2;
          _sparkle(canvas, d.pos.translate(10, -26 * d.scale), 3 + a * 3, Colors.white.withValues(alpha: a));
        case Deco.crack:
          final a = (sin(t * 2 + ph) + 1) / 2;
          canvas.drawCircle(d.pos, 10, _p(const Color(0xFFF0582A).withValues(alpha: a * .18)));
        case Deco.lantern when night:
          final a = (sin(t * 3 + ph) + 1) / 2;
          canvas.drawCircle(d.pos.translate(0, -15), 16 + a * 4, _p(const Color(0xFFFFC233).withValues(alpha: .12 + a * .12)));
        default:
          break;
      }
    }

    for (final r in layout.rivers) {
      if (r.kind != RiverKind.lava || (r.crossing.dy - y0) < -60 || (r.crossing.dy - y1) > 60) continue;
      for (var i = 0; i < 5; i++) {
        final k = (t * .4 + i * .2) % 1.0;
        final x = layout.width * (.12 + i * .19);
        canvas.drawCircle(Offset(x, r.crossing.dy - k * 34), 2, _p(const Color(0xFFFFC233).withValues(alpha: 1 - k)));
      }
    }

    if (frost) {
      final rng = Random(3);
      for (var i = 0; i < 22; i++) {
        final x = rng.nextDouble() * layout.width;
        final speed = .5 + rng.nextDouble() * .5;
        final y = y0 + ((rng.nextDouble() + t * .05 * speed) % 1.0) * (y1 - y0);
        canvas.drawCircle(Offset(x + sin(t + i) * 6, y), 1.4 + rng.nextDouble() * 1.4, _p(Colors.white.withValues(alpha: .8)));
      }
    }

    if (!night) {
      for (var cy = 500.0; cy < layout.height; cy += 950) {
        if (cy < y0 - 60 || cy > y1 + 60) continue;
        final dx = sin(t * .3 + cy) * 30;
        _cloud(canvas, Offset((cy ~/ 950).isEven ? layout.width * .82 + dx : layout.width * .14 + dx, cy), .9);
      }
      for (var by = 300.0; by < layout.height; by += 1300) {
        if (by < y0 || by > y1) continue;
        final p = Offset(layout.width * .7 + sin(t * .5) * 20, by + cos(t * .5) * 8);
        final wing = sin(t * 6) * 3;
        final bird = _s(const Color(0xFF13213C), 1.8);
        for (final o in const [Offset(0, 0), Offset(16, -8)]) {
          final q = p + o;
          canvas.drawPath(Path()..moveTo(q.dx - 7, q.dy)..quadraticBezierTo(q.dx - 3, q.dy - 5 - wing, q.dx, q.dy)..quadraticBezierTo(q.dx + 3, q.dy - 5 - wing, q.dx + 7, q.dy), bird);
        }
      }
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
    c.drawPath(p, _p(col));
  }

  void _cloud(Canvas c, Offset at, double s) {
    final w = _p(Colors.white.withValues(alpha: .9));
    c.drawOval(Rect.fromCenter(center: at.translate(0, 6 * s), width: 68 * s, height: 18 * s), w);
    c.drawCircle(at.translate(-14 * s, 0), 12 * s, w);
    c.drawCircle(at.translate(4 * s, -7 * s), 16 * s, w);
    c.drawCircle(at.translate(20 * s, s), 11 * s, w);
  }

  @override
  bool shouldRepaint(AmbientPainter old) => old.top != top || old.night != night;
}
