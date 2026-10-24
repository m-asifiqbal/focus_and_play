// Each island's colour set. The four hues were checked as a chart palette
// (colour-blind and normal-vision separation) — keep them in sync with Insights.

import 'package:flutter/material.dart';

import '../../domain/game_id.dart';
import 'mi_colors.dart';

/// Colours for one island in the current theme.
class IslandStyle {
  const IslandStyle({
    required this.color,
    required this.ledge,
    required this.tint,
    required this.ink,
    required this.onColor,
    required this.page,
    required this.cardLedge,
  });

  /// Fill for buttons, paths and finished level pads.
  final Color color;

  /// Solid ledge under [color] buttons.
  final Color ledge;

  /// Soft background (cells, tracks).
  final Color tint;

  /// Text in the island colour on a light/dark card (passes 4.5:1).
  final Color ink;

  /// Text on top of [color].
  final Color onColor;

  /// Screen ground on the game screen.
  final Color page;

  /// Ledge under white cards on this island's screens.
  final Color cardLedge;

  static IslandStyle of(GameId g, MiColors c) => c.isNight ? _night[g]! : _day[g]!;

  static const Map<GameId, IslandStyle> _day = {
    GameId.thread: IslandStyle(color: Color(0xFFF0582A), ledge: Color(0xFFB93C14), tint: Color(0xFFFFE5D9), ink: Color(0xFF9A3412), onColor: Colors.white, page: Color(0xFFFFF4EE), cardLedge: Color(0xFFF3CDBB)),
    GameId.quilt: IslandStyle(color: Color(0xFF1F9D55), ledge: Color(0xFF15703B), tint: Color(0xFFDDF5E6), ink: Color(0xFF166534), onColor: Colors.white, page: Color(0xFFF1FAF4), cardLedge: Color(0xFFC7E6D2)),
    GameId.twist: IslandStyle(color: Color(0xFF8A4FD8), ledge: Color(0xFF6B35C4), tint: Color(0xFFECE6FD), ink: Color(0xFF5B2BA6), onColor: Colors.white, page: Color(0xFFF6F3FF), cardLedge: Color(0xFFD8CEF7)),
    GameId.sudoku: IslandStyle(color: Color(0xFF1E9BDC), ledge: Color(0xFF1D6BB0), tint: Color(0xFFDCEEFC), ink: Color(0xFF1E4E8C), onColor: Color(0xFF0D1626), page: Color(0xFFF0F7FE), cardLedge: Color(0xFFBFD9F2)),
  };

  static const Map<GameId, IslandStyle> _night = {
    GameId.thread: IslandStyle(color: Color(0xFFF0582A), ledge: Color(0xFF8E2E10), tint: Color(0xFF3A2219), ink: Color(0xFFFF9A70), onColor: Colors.white, page: Color(0xFF0D1626), cardLedge: Color(0xFF0A1220)),
    GameId.quilt: IslandStyle(color: Color(0xFF1F9D55), ledge: Color(0xFF0F5A30), tint: Color(0xFF123526), ink: Color(0xFF6FD69A), onColor: Colors.white, page: Color(0xFF0D1626), cardLedge: Color(0xFF0A1220)),
    GameId.twist: IslandStyle(color: Color(0xFF8A4FD8), ledge: Color(0xFF52279A), tint: Color(0xFF291F4A), ink: Color(0xFFC3A4F5), onColor: Colors.white, page: Color(0xFF0D1626), cardLedge: Color(0xFF0A1220)),
    GameId.sudoku: IslandStyle(color: Color(0xFF1E9BDC), ledge: Color(0xFF155E8C), tint: Color(0xFF132E49), ink: Color(0xFF7CC4F2), onColor: Color(0xFF0D1626), page: Color(0xFF0D1626), cardLedge: Color(0xFF0A1220)),
  };
}

extension IslandStyleX on BuildContext {
  IslandStyle island(GameId g) => IslandStyle.of(g, mi);
}
