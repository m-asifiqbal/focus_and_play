// Renders a widget at phone size with the real fonts and writes a PNG to
// build/screens/<name>.png — for eyeballing screens without a device.
// (File name must not end in _test.dart: it is a helper, not a test.)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Loads Fredoka, Nunito and the Material icon font so captures look real.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<ByteData> bytes(String path) async => ByteData.view(File(path).readAsBytesSync().buffer);
  final fredoka = FontLoader('Fredoka');
  for (final w in ['Medium', 'SemiBold', 'Bold']) {
    fredoka.addFont(bytes('assets/fonts/Fredoka-$w.ttf'));
  }
  await fredoka.load();
  final nunito = FontLoader('Nunito');
  for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(bytes('assets/fonts/Nunito-$w.ttf'));
  }
  await nunito.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(bytes(icons.path));
      await loader.load();
    }
  }
}

/// Sets the test view to a phone (390×844 pt at 3×).
void usePhoneView(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

final _captureKey = GlobalKey();

/// Wraps [child] so [capture] can find it.
Widget capturable(Widget child) => RepaintBoundary(key: _captureKey, child: child);

/// Writes the current frame of the [capturable] widget to build/screens/[name].png.
Future<void> capture(WidgetTester tester, String name, {double pixelRatio = 2}) async {
  final boundary = _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screens/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}
