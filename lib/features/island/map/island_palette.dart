// Looks of each island's four zones (one per tier): ground colour, scenery mix,
// the kind of river that crosses the road, and zone names for the signposts.

import 'package:flutter/material.dart';

import '../../../domain/game_id.dart';

/// Scenery sprites the painter knows how to draw.
enum Deco {
  palm,
  bush,
  flower,
  shell,
  pool,
  rock,
  darkRock,
  hexCluster,
  crack,
  iceCrack,
  vent,
  lavaPool,
  field,
  hay,
  windmill,
  sheep,
  fruitTree,
  crystalSmall,
  crystalBig,
  mushroom,
  violetRock,
  pine,
  drift,
  ice,
  lantern,
}

enum RiverKind { stream, lava, glow, ice }

class ZoneStyle {
  const ZoneStyle(this.name, this.ground, this.edge, this.decos, this.river);
  final String name;
  final Color ground;

  /// Darker shade for the zone boundary and the road border.
  final Color edge;

  /// Weighted scenery list (repeat an entry to make it more common).
  final List<Deco> decos;
  final RiverKind river;
}

class IslandPalette {
  const IslandPalette({required this.zones, required this.shore, required this.accent, required this.accentLedge, required this.summit});
  final List<ZoneStyle> zones;
  final Color shore;
  final Color accent;
  final Color accentLedge;

  /// What sits at the top of the island.
  final Summit summit;

  static const sea = Color(0xFF86CFEA);
  static const seaNight = Color(0xFF12304E);
  static const road = Color(0xFFF2E4CF);

  static IslandPalette of(GameId g) => switch (g) {
        GameId.thread => const IslandPalette(
            shore: Color(0xFFE9CF9E),
            accent: Color(0xFFF0582A),
            accentLedge: Color(0xFFB93C14),
            summit: Summit.crater,
            zones: [
              ZoneStyle('Ember Cove', Color(0xFFF4DDB0), Color(0xFFD9BE8A), [Deco.palm, Deco.shell, Deco.pool, Deco.palm, Deco.shell], RiverKind.stream),
              ZoneStyle('Palm Jungle', Color(0xFF8ACB8E), Color(0xFF6CAE73), [Deco.palm, Deco.bush, Deco.flower, Deco.bush, Deco.palm], RiverKind.stream),
              ZoneStyle('Basalt Cliffs', Color(0xFFBDA28C), Color(0xFF8C7362), [Deco.hexCluster, Deco.rock, Deco.crack, Deco.vent, Deco.lavaPool], RiverKind.lava),
              ZoneStyle('Crater Summit', Color(0xFF776359), Color(0xFF5A4A42), [Deco.lavaPool, Deco.darkRock, Deco.crack, Deco.darkRock, Deco.vent], RiverKind.lava),
            ],
          ),
        GameId.quilt => const IslandPalette(
            shore: Color(0xFFEAD3A6),
            accent: Color(0xFF1F9D55),
            accentLedge: Color(0xFF15703B),
            summit: Summit.bigTree,
            zones: [
              ZoneStyle('Sandy Shore', Color(0xFFF4DDB0), Color(0xFFD9BE8A), [Deco.palm, Deco.shell, Deco.bush, Deco.pool], RiverKind.stream),
              ZoneStyle('Patchwork Fields', Color(0xFFA6D98F), Color(0xFF7DB86B), [Deco.field, Deco.field, Deco.hay, Deco.flower, Deco.bush], RiverKind.stream),
              ZoneStyle('Windmill Hills', Color(0xFF86C97E), Color(0xFF63A85C), [Deco.windmill, Deco.sheep, Deco.sheep, Deco.fruitTree, Deco.flower], RiverKind.stream),
              ZoneStyle('Orchard Summit', Color(0xFF66B06C), Color(0xFF4A8F51), [Deco.fruitTree, Deco.fruitTree, Deco.bush, Deco.flower], RiverKind.stream),
            ],
          ),
        GameId.twist => const IslandPalette(
            shore: Color(0xFFEAD3A6),
            accent: Color(0xFF8A4FD8),
            accentLedge: Color(0xFF6B35C4),
            summit: Summit.spire,
            zones: [
              ZoneStyle('Moon Lagoon', Color(0xFFF2E2C4), Color(0xFFD8C39C), [Deco.shell, Deco.pool, Deco.crystalSmall, Deco.palm], RiverKind.glow),
              ZoneStyle('Glow Caves', Color(0xFFD3C8EE), Color(0xFFAE9FD8), [Deco.mushroom, Deco.crystalSmall, Deco.violetRock, Deco.mushroom], RiverKind.glow),
              ZoneStyle('Prism Gorge', Color(0xFFAE98DE), Color(0xFF8A72C4), [Deco.crystalBig, Deco.crystalSmall, Deco.violetRock, Deco.crystalSmall], RiverKind.glow),
              ZoneStyle('Crystal Spire', Color(0xFF8169C4), Color(0xFF6650A8), [Deco.crystalBig, Deco.crystalBig, Deco.violetRock, Deco.crystalSmall], RiverKind.glow),
            ],
          ),
        GameId.sudoku => const IslandPalette(
            shore: Color(0xFFC9D8E8),
            accent: Color(0xFF1E9BDC),
            accentLedge: Color(0xFF155E8C),
            summit: Summit.peak,
            zones: [
              ZoneStyle('Ice Floes', Color(0xFFEAF3FB), Color(0xFFC9DCEE), [Deco.ice, Deco.drift, Deco.rock, Deco.ice], RiverKind.ice),
              ZoneStyle('Pine Forest', Color(0xFFD9E7F3), Color(0xFFB2C8DE), [Deco.pine, Deco.pine, Deco.drift, Deco.lantern, Deco.pine], RiverKind.ice),
              ZoneStyle('Glacier', Color(0xFFC4DCEF), Color(0xFF98B9D6), [Deco.ice, Deco.iceCrack, Deco.pine, Deco.drift], RiverKind.ice),
              ZoneStyle('Aurora Peak', Color(0xFFADC6E0), Color(0xFF86A4C4), [Deco.rock, Deco.drift, Deco.pine, Deco.ice], RiverKind.ice),
            ],
          ),
      };
}

enum Summit { crater, bigTree, spire, peak }
