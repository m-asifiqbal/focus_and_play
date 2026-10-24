// Geometry of an island map: where the 60 level pads sit, the road through them,
// the shoreline, zone boundaries, rivers with bridges and every piece of scenery.
//
// Why precomputed: the painter and the level-pad widgets must agree exactly, and
// the scenery must not move between visits — everything comes from a fixed seed.

import 'dart:math';
import 'dart:ui';

import '../../../domain/game_id.dart';
import '../../../domain/tier.dart';
import 'island_palette.dart';

/// One cubic road segment.
class RoadSeg {
  const RoadSeg(this.a, this.c1, this.c2, this.b);
  final Offset a, c1, c2, b;

  Offset at(double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        c1 * (3 * u * u * t) +
        c2 * (3 * u * t * t) +
        b * (t * t * t);
  }
}

class DecoSpot {
  const DecoSpot(this.kind, this.pos, this.scale, this.zone, this.variant);
  final Deco kind;
  final Offset pos;
  final double scale;
  final int zone;
  final int variant;
}

class RiverCrossing {
  const RiverCrossing(
    this.zone,
    this.crossing,
    this.angle,
    this.path,
    this.kind,
  );
  final int zone;
  final Offset crossing;

  /// Road direction at the crossing (radians) — the bridge is drawn along it.
  final double angle;
  final Path path;
  final RiverKind kind;
}

class IslandLayout {
  IslandLayout._(
    this.game,
    this.width,
    this.height,
    this.nodes,
    this.road,
    this.zoneBounds,
    this.decos,
    this.rivers,
    this.roadSamples,
  );

  static const spacing = 116.0;
  static const bottomPad = 250.0;
  static const topPad = 300.0;

  final GameId game;
  final double width;
  final double height;

  /// Centre of level pad i (index 0 = level 1).
  final List<Offset> nodes;

  /// Road from the dock (index 0) through every level to the summit.
  final List<RoadSeg> road;

  /// y of the boundary below zone 1, 2 and 3 (Easy|Medium, Medium|Hard, Hard|Expert).
  final List<double> zoneBounds;
  final List<DecoSpot> decos;
  final List<RiverCrossing> rivers;

  /// Points along the road every few px (for distance tests and the done-overlay).
  final List<Offset> roadSamples;

  /// Road segment index that ends at level [level]'s pad.
  static int segEndingAt(int level) =>
      level; // seg 0: dock→L1, seg k: L(k)→L(k+1)

  int zoneAt(double y) => y > zoneBounds[0]
      ? 0
      : (y > zoneBounds[1] ? 1 : (y > zoneBounds[2] ? 2 : 3));

  double leftEdge(double y) {
    final taperTop = y < 700 ? (700 - y) * .12 : 0.0;
    final taperBot = y > height - 180 ? (y - (height - 180)) * .35 : 0.0;
    return width * .085 + width * .03 * sin(y / 95) + taperTop + taperBot;
  }

  double rightEdge(double y) {
    final taperTop = y < 700 ? (700 - y) * .12 : 0.0;
    final taperBot = y > height - 180 ? (y - (height - 180)) * .35 : 0.0;
    return width * .915 -
        width * .03 * sin(y / 120 + 1.3) -
        taperTop -
        taperBot;
  }

  Offset nodeOf(int level) => nodes[level - 1];

  /// y where level [level]'s pad sits (scroll anchor).
  double yOf(int level) => nodes[level - 1].dy;

  static IslandLayout build(GameId game, double width) {
    final height = bottomPad + (Levels.perIsland - 1) * spacing + topPad;
    final amp = width * .235;
    final cx = width / 2;
    final nodes = <Offset>[
      for (var i = 0; i < Levels.perIsland; i++)
        Offset(
          cx +
              amp *
                  (i > 55 ? (1 - (i - 55) / 6) : 1) *
                  sin(i * .62 + game.index * .9),
          height - bottomPad - i * spacing,
        ),
    ];
    final pts = [
      Offset(cx - width * .12, height - 70),
      Offset(cx - width * .08, height - 150),
      ...nodes,
      Offset(cx, 150),
    ];
    final segs = _catmull(pts);
    // road: seg 0 = dock→p1 (extra), seg1 = p1→L1 … keep dock→L1 as segment 0 by merging.
    final road = [segs[0], segs[1], ...segs.sublist(2)];
    final samples = <Offset>[
      for (final s in road)
        for (var t = 0.0; t < 1; t += .04) s.at(t),
    ];
    final bounds = [
      (nodes[14].dy + nodes[15].dy) / 2,
      (nodes[29].dy + nodes[30].dy) / 2,
      (nodes[44].dy + nodes[45].dy) / 2,
    ];
    final layout = IslandLayout._(
      game,
      width,
      height,
      nodes,
      road,
      bounds,
      const [],
      const [],
      samples,
    );
    final rivers = _rivers(layout, game, road);
    final decos = _decos(layout, game, samples, rivers);
    return IslandLayout._(
      game,
      width,
      height,
      nodes,
      road,
      bounds,
      decos,
      rivers,
      samples,
    );
  }

  static List<RoadSeg> _catmull(List<Offset> p) => [
    for (var i = 0; i < p.length - 1; i++)
      RoadSeg(
        p[i],
        p[i] + (p[min(p.length - 1, i + 1)] - p[max(0, i - 1)]) / 6,
        p[i + 1] - (p[min(p.length - 1, i + 2)] - p[i]) / 6,
        p[i + 1],
      ),
  ];

  static List<RiverCrossing> _rivers(
    IslandLayout l,
    GameId game,
    List<RoadSeg> road,
  ) {
    final pal = IslandPalette.of(game);
    final out = <RiverCrossing>[];
    for (var z = 0; z < 4; z++) {
      // Between levels 7 and 8 of each tier: road segment index = level (see segEndingAt).
      final seg = road[z * Levels.perTier + 8];
      final c = seg.at(.5);
      final d = seg.at(.55) - seg.at(.45);
      final angle = atan2(d.dy, d.dx);
      final left = Offset(0, c.dy + 30);
      final right = Offset(l.width, c.dy - 6);
      final path = Path()
        ..moveTo(left.dx - 10, left.dy)
        ..cubicTo(l.width * .2, c.dy - 6, c.dx - 70, c.dy + 26, c.dx, c.dy)
        ..cubicTo(
          c.dx + 70,
          c.dy - 26,
          l.width * .8,
          c.dy + 26,
          right.dx + 10,
          right.dy,
        );
      out.add(RiverCrossing(z, c, angle, path, pal.zones[z].river));
    }
    return out;
  }

  static List<DecoSpot> _decos(
    IslandLayout l,
    GameId game,
    List<Offset> samples,
    List<RiverCrossing> rivers,
  ) {
    final rng = Random(9001 + game.index * 77);
    final pal = IslandPalette.of(game);
    final out = <DecoSpot>[];
    bool nearRoad(Offset p, double d) {
      for (final s in samples) {
        if ((s.dy - p.dy).abs() > d) continue;
        if ((s - p).distance < d) return true;
      }
      return false;
    }

    bool nearRiver(Offset p) =>
        rivers.any((r) => (p.dy - r.crossing.dy).abs() < 44);
    const step = 44.0;
    for (var y = 120.0; y < l.height - 60; y += step) {
      for (var k = 0; k < 6; k++) {
        if (rng.nextDouble() < .45) continue;
        final lx = l.leftEdge(y) + 22, rx = l.rightEdge(y) - 22;
        if (rx <= lx) continue;
        final p = Offset(
          lx + rng.nextDouble() * (rx - lx),
          y + rng.nextDouble() * step,
        );
        if (nearRoad(p, 40) || nearRiver(p)) continue;
        if (p.dy < 300 && (p.dx - l.width / 2).abs() < l.width * .25) {
          continue; // summit landmark
        }
        if (p.dy > l.height - 200 && (p.dx - l.width * .4).abs() < 70) {
          continue; // dock
        }
        if (out.any((o) => (o.pos - p).distance < 30)) continue;
        final z = l.zoneAt(p.dy);
        final list = pal.zones[z].decos;
        out.add(
          DecoSpot(
            list[rng.nextInt(list.length)],
            p,
            .85 + rng.nextDouble() * .35,
            z,
            rng.nextInt(4),
          ),
        );
      }
    }
    out.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    return out;
  }
}
