// What Thread actually draws: the thread eased along its path instead of snapping
// from square to square.
//
// The controller's path jumps by whole squares (a fast swipe can add five at once).
// Drawing that directly looks jerky, so the display keeps its own fractional head
// position that glides towards the real one — growing the line smoothly, and when
// the player slides back, drawing the line back in rather than deleting squares.
// Pure Dart: tested without a widget.

import 'dart:math';
import 'dart:ui';

class ThreadTrail {
  /// The cells currently drawn (may be longer than the real path while the line is
  /// still retracting).
  List<int> cells = [];

  /// Where the drawn head is, as a fractional index into [cells] (2.5 = halfway
  /// between the third and fourth cell).
  double shown = 0;

  /// Where the head is heading: the index of the path's last cell.
  double target = 0;

  int _len = 0;

  /// Speed: the gap closes by about this many "e-folds" per second…
  static const _ease = 16.0;

  /// …but never slower than this many squares per second, so long slides finish.
  static const _minSpeed = 9.0;

  /// Tells the trail where the real path is now.
  void follow(List<int> path) {
    var k = 0;
    final m = min(cells.length, path.length);
    while (k < m && cells[k] == path[k]) {
      k++;
    }
    _len = path.length;
    target = max(0, path.length - 1).toDouble();
    if (k == path.length && path.length < cells.length) {
      // The player slid back: keep drawing the old tail until the head has
      // travelled back to the new end.
      return;
    }
    // Grew, or took a different route (undo, hint, reset): only the part that is
    // still valid may stay drawn; the rest grows from there.
    shown = min(shown, max(0, k - 1).toDouble());
    cells = List.of(path);
  }

  /// Moves the head [dt] seconds towards its target. True while still moving.
  bool step(double dt) {
    final d = target - shown;
    if (d.abs() < .005) {
      shown = target;
      _settle();
      return false;
    }
    var move = d * (1 - exp(-dt * _ease));
    final least = min(d.abs(), _minSpeed * dt);
    if (move.abs() < least) move = least * d.sign;
    shown += move;
    return true;
  }

  /// Jumps straight to the target (reduce motion).
  void snap() {
    shown = target;
    _settle();
  }

  bool get moving => (target - shown).abs() >= .005;

  /// Once the head is back, forget the retracted tail.
  void _settle() {
    if (cells.length > _len) cells = cells.sublist(0, _len);
  }

  /// The polyline to draw, ending exactly at the (possibly fractional) head.
  List<Offset> points(Offset Function(int cell) center) {
    if (cells.isEmpty) return const [];
    final i = min(shown.floor(), cells.length - 1);
    final f = shown - i;
    return [
      for (var k = 0; k <= i; k++) center(cells[k]),
      if (f > .001 && i + 1 < cells.length)
        Offset.lerp(center(cells[i]), center(cells[i + 1]), f)!,
    ];
  }
}

/// A path through [pts] with every corner rounded by up to [radius], so the thread
/// bends instead of turning in sharp elbows.
Path smoothPath(List<Offset> pts, double radius) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final prev = pts[i - 1], cur = pts[i], next = pts[i + 1];
    final toPrev = prev - cur, toNext = next - cur;
    if (toPrev.distance < 1e-6 || toNext.distance < 1e-6) continue;
    final a = cur + toPrev / toPrev.distance * min(radius, toPrev.distance / 2);
    final b = cur + toNext / toNext.distance * min(radius, toNext.distance / 2);
    path.lineTo(a.dx, a.dy);
    path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}
