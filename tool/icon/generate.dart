// Draws the app icon (the splash's four-isles logo on night navy) and writes
// every launcher size: Android legacy + adaptive (foreground, monochrome),
// iOS AppIcon set and the 512 px Play Store icon.
//
// No packages and no image editor needed: shapes are signed-distance
// functions, anti-aliased by 4×4 supersampling, encoded as PNG with dart:io's
// zlib. Run from the project root after changing the logo:
//
//   dart tool/icon/generate.dart            (add `--out <dir>` to preview)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const navy = 0xFF13213C;
const sun = 0xFFFFC233;
const white = 0xFFFFFFFF;
// Ember, Meadow, Crystal, Frost — the same order as the splash.
const isles = [0xFFF0582A, 0xFF1F9D55, 0xFF8A4FD8, 0xFF1E9BDC];

/// One layer: a shape, painted in [color] (or cleared when [erase]).
class Op {
  Op(this.inside, this.color, {this.erase = false});
  final bool Function(double x, double y) inside;
  final int color;
  final bool erase;
}

bool Function(double, double) roundRect(
  double cx,
  double cy,
  double hx,
  double hy,
  double r,
) => (x, y) {
  final qx = (x - cx).abs() - (hx - r);
  final qy = (y - cy).abs() - (hy - r);
  final ox = math.max(qx, 0.0), oy = math.max(qy, 0.0);
  return math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0.0) - r <=
      0;
};

bool Function(double, double) circle(double cx, double cy, double r) =>
    (x, y) => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;

int darker(int argb, double f) {
  int ch(int s) => (((argb >> s) & 0xFF) * f).round() << s;
  return 0xFF000000 | ch(16) | ch(8) | ch(0);
}

/// The logo, [width] px wide, centred in a [size] px canvas.
/// Logo units: four 40-unit squares with an 8-unit gap (88 wide), a 5-unit
/// "ledge" under each (the app's pressable look) and the sun in the middle.
List<Op> logo(double size, double width, {bool mono = false}) {
  final k = width / 88;
  final c = size / 2;
  final lift = mono ? 0.0 : 2.5; // centre the squares + ledge visually
  final ops = <Op>[];
  for (var i = 0; i < 4; i++) {
    final cx = c + (i.isOdd ? 24 : -24) * k;
    final cy = c + (i >= 2 ? 24 : -24) * k - lift * k;
    if (!mono) {
      ops.add(
        Op(
          roundRect(cx, cy + 5 * k, 20 * k, 20 * k, 14 * k),
          darker(isles[i], 0.72),
        ),
      );
    }
    ops.add(
      Op(roundRect(cx, cy, 20 * k, 20 * k, 14 * k), mono ? white : isles[i]),
    );
  }
  // The sun sits in the cross-shaped gap, which stays at the centre after the lift.
  ops.add(Op(circle(c, c, 13 * k), navy, erase: mono));
  ops.add(Op(circle(c, c, 9 * k), mono ? white : sun));
  return ops;
}

/// Rasterises [ops] (painter's order) into straight-alpha RGBA.
Uint8List render(int n, List<Op> ops) {
  const ss = 4;
  final out = Uint8List(n * n * 4);
  for (var py = 0; py < n; py++) {
    for (var px = 0; px < n; px++) {
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final x = px + (sx + 0.5) / ss, y = py + (sy + 0.5) / ss;
          var col = 0, alpha = 0;
          for (final op in ops) {
            if (!op.inside(x, y)) continue;
            col = op.color;
            alpha = op.erase ? 0 : 1;
          }
          if (alpha == 0) continue;
          r += (col >> 16) & 0xFF;
          g += (col >> 8) & 0xFF;
          b += col & 0xFF;
          a += 1;
        }
      }
      final o = (py * n + px) * 4;
      if (a > 0) {
        out[o] = (r / a).round();
        out[o + 1] = (g / a).round();
        out[o + 2] = (b / a).round();
      }
      out[o + 3] = (a / (ss * ss) * 255).round();
    }
  }
  return out;
}

// ---------- PNG ----------

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  final head = ByteData(4)..setUint32(0, data.length);
  out.add(head.buffer.asUint8List());
  final body = [...ascii.encode(type), ...data];
  out.add(body);
  final crc = ByteData(4)..setUint32(0, _crc(body));
  out.add(crc.buffer.asUint8List());
}

/// Encodes RGBA pixels; [opaque] drops the alpha channel (App Store icons
/// must not have one).
Uint8List png(int n, Uint8List rgba, {bool opaque = false}) {
  final ch = opaque ? 3 : 4;
  final raw = BytesBuilder();
  for (var y = 0; y < n; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < n; x++) {
      final o = (y * n + x) * 4;
      raw.add(rgba.sublist(o, o + ch));
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, n)
    ..setUint32(4, n)
    ..setUint8(8, 8)
    ..setUint8(9, opaque ? 2 : 6);
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(out, 'IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes()));
  _chunk(out, 'IEND', const []);
  return out.takeBytes();
}

/// Where files go; `--out <dir>` previews them somewhere else.
var outRoot = '.';

void write(String path, int n, List<Op> ops, {bool opaque = false}) {
  File('$outRoot/$path')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png(n, render(n, ops), opaque: opaque));
  stdout.writeln('  $path ($n px)');
}

void main(List<String> args) {
  final at = args.indexOf('--out');
  if (at >= 0 && at + 1 < args.length) outRoot = args[at + 1];
  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  // Android < 8: a navy tile with rounded corners (48 dp, 1 dp inset).
  // Android 8+: adaptive icon — navy background colour + a 108 dp foreground
  // whose logo stays inside the 66 dp safe circle every launcher mask keeps.
  densities.forEach((name, d) {
    final legacy = (48 * d).round();
    write('$res/mipmap-$name/ic_launcher.png', legacy, [
      Op(
        roundRect(
          legacy / 2,
          legacy / 2,
          legacy / 2 - d,
          legacy / 2 - d,
          legacy * 0.22,
        ),
        navy,
      ),
      ...logo(legacy.toDouble(), legacy * 0.56),
    ]);
    final fg = (108 * d).round();
    write(
      '$res/mipmap-$name/ic_launcher_foreground.png',
      fg,
      logo(fg.toDouble(), fg * 0.45),
    );
    write(
      '$res/mipmap-$name/ic_launcher_monochrome.png',
      fg,
      logo(fg.toDouble(), fg * 0.45, mono: true),
    );
  });

  // iOS: full-bleed and opaque; the system rounds the corners.
  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final contents = jsonDecode(
    File('$iosDir/Contents.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final done = <String>{};
  for (final img in (contents['images'] as List).cast<Map<String, dynamic>>()) {
    final file = img['filename'] as String?;
    if (file == null || !done.add(file)) continue;
    final pt = double.parse((img['size'] as String).split('x').first);
    final scale = double.parse((img['scale'] as String).replaceAll('x', ''));
    final n = (pt * scale).round();
    write('$iosDir/$file', n, [
      Op((_, _) => true, navy),
      ...logo(n.toDouble(), n * 0.58),
    ], opaque: true);
  }

  // Play Store listing icon: 512 px, full square (Play applies its own mask).
  write('store/play_icon_512.png', 512, [
    Op((_, _) => true, navy),
    ...logo(512, 512 * 0.56),
  ]);
}
