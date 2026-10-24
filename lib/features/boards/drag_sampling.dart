// Fills in a fast drag: pointer updates arrive once per frame, so a quick swipe
// can jump past whole squares. Boards walk the straight line between two
// updates in small steps instead, so every square the finger crossed counts.

import 'dart:math';
import 'dart:ui';

/// Points from just after [from] up to and including [to], at most [step] px apart.
Iterable<Offset> pointsAlong(Offset from, Offset to, double step) sync* {
  final d = to - from;
  final n = max(1, (d.distance / max(1.0, step)).ceil());
  for (var i = 1; i <= n; i++) {
    yield from + d * (i / n);
  }
}
