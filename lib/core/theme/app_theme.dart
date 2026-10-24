// Material theme built from the MiColors tokens, plus the text styles.
//
// Fonts are bundled (offline): Fredoka for headings, numbers and buttons,
// Nunito for body text.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'mi_colors.dart';

abstract final class MiFonts {
  static const display = 'Fredoka';
  static const body = 'Nunito';
}

/// Text styles. Colours come from the theme unless a widget overrides them.
abstract final class MiText {
  static const hero = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );
  static const display = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const title = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const headline = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const number = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );
  static const button = TextStyle(
    fontFamily: MiFonts.display,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );
  static const body = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );
  static const bodyStrong = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.4,
  );
  static const label = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const small = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
  static const caption = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const overline = TextStyle(
    fontFamily: MiFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: .5,
    height: 1.2,
  );
}

abstract final class AppTheme {
  static ThemeData build(MiColors c) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.brand,
          brightness: c.isNight ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: c.brand,
          onPrimary: c.onBrand,
          surface: c.card,
          onSurface: c.ink,
          error: c.danger,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.page,
      fontFamily: MiFonts.body,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: c.ink,
        displayColor: c.ink,
        fontFamily: MiFonts.body,
      ),
      iconTheme: IconThemeData(color: c.ink),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isNight ? c.sunk : c.navy,
        contentTextStyle: MiText.label.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
