// Colour tokens for the whole app as a ThemeExtension, with Day and Night sets.
//
// Why: screens read `context.mi` instead of hard-coded colours, so the
// Day / Night / System setting restyles everything for free. Island colours
// live in island_style.dart.

import 'package:flutter/material.dart';

/// Semantic colour tokens (Day and Night).
@immutable
class MiColors extends ThemeExtension<MiColors> {
  const MiColors({
    required this.page,
    required this.card,
    required this.sunk,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.ledge,
    required this.brand,
    required this.brandLedge,
    required this.brandTint,
    required this.brandInk,
    required this.onBrand,
    required this.sun,
    required this.sunLedge,
    required this.sunTint,
    required this.sunInk,
    required this.heart,
    required this.heartTint,
    required this.danger,
    required this.navy,
    required this.scrim,
    required this.isNight,
  });

  final Color page, card, sunk, ink, inkSoft, line, ledge;
  final Color brand, brandLedge, brandTint, brandInk, onBrand;
  final Color sun, sunLedge, sunTint, sunInk;
  final Color heart, heartTint, danger, navy, scrim;
  final bool isNight;

  static const day = MiColors(
    page: Color(0xFFEEF5FB),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFE3ECF5),
    ink: Color(0xFF13213C),
    inkSoft: Color(0xFF4E5E7A),
    line: Color(0xFFD5E1EC),
    ledge: Color(0xFFD5E1EC),
    brand: Color(0xFF0A7C70),
    brandLedge: Color(0xFF06564E),
    brandTint: Color(0xFFD7F2EE),
    brandInk: Color(0xFF0A7C70),
    onBrand: Color(0xFFFFFFFF),
    sun: Color(0xFFFFC233),
    sunLedge: Color(0xFFDB9A00),
    sunTint: Color(0xFFFFF1CC),
    sunInk: Color(0xFF6B4A00),
    heart: Color(0xFFE8365D),
    heartTint: Color(0xFFFDE2E8),
    danger: Color(0xFFB4183F),
    navy: Color(0xFF13213C),
    scrim: Color(0xB813213C),
    isNight: false,
  );

  static const night = MiColors(
    page: Color(0xFF0D1626),
    card: Color(0xFF16223A),
    sunk: Color(0xFF24324D),
    ink: Color(0xFFEAF1FB),
    inkSoft: Color(0xFFA9B9D1),
    line: Color(0xFF24324D),
    ledge: Color(0xFF0A1220),
    brand: Color(0xFF0A7C70),
    brandLedge: Color(0xFF06564E),
    brandTint: Color(0xFF12403B),
    brandInk: Color(0xFF5FD6C5),
    onBrand: Color(0xFFFFFFFF),
    sun: Color(0xFFFFC233),
    sunLedge: Color(0xFFDB9A00),
    sunTint: Color(0xFF3A3014),
    sunInk: Color(0xFFFFD66B),
    heart: Color(0xFFFF5C80),
    heartTint: Color(0xFF3A1A24),
    danger: Color(0xFFFF8FA3),
    navy: Color(0xFF13213C),
    scrim: Color(0xC40D1626),
    isNight: true,
  );

  @override
  MiColors copyWith() => this;

  @override
  MiColors lerp(ThemeExtension<MiColors>? other, double t) {
    if (other is! MiColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MiColors(
      page: c(page, other.page),
      card: c(card, other.card),
      sunk: c(sunk, other.sunk),
      ink: c(ink, other.ink),
      inkSoft: c(inkSoft, other.inkSoft),
      line: c(line, other.line),
      ledge: c(ledge, other.ledge),
      brand: c(brand, other.brand),
      brandLedge: c(brandLedge, other.brandLedge),
      brandTint: c(brandTint, other.brandTint),
      brandInk: c(brandInk, other.brandInk),
      onBrand: c(onBrand, other.onBrand),
      sun: c(sun, other.sun),
      sunLedge: c(sunLedge, other.sunLedge),
      sunTint: c(sunTint, other.sunTint),
      sunInk: c(sunInk, other.sunInk),
      heart: c(heart, other.heart),
      heartTint: c(heartTint, other.heartTint),
      danger: c(danger, other.danger),
      navy: c(navy, other.navy),
      scrim: c(scrim, other.scrim),
      isNight: t < .5 ? isNight : other.isNight,
    );
  }
}

/// `context.mi` — the active colour tokens.
extension MiColorsX on BuildContext {
  MiColors get mi => Theme.of(this).extension<MiColors>() ?? MiColors.day;
}
