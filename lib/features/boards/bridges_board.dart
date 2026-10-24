// Bridges: join the islets with bridges so every islet has exactly its number, no
// bridge crosses another, and all the islets form one group.
//
// Two ways to build: tap the gap between two islets (none → 1 → 2 → none), or drag
// from one islet towards another. Dashed guides show every possible bridge, so the
// player is never hunting for where one can go.

import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_banner.dart';
import '../../domain/game_id.dart';
import '../../state/save_controller.dart';
import 'bridges_controller.dart';
import 'bridges_painter.dart';

export 'bridges_controller.dart';

class BridgesBoard extends ConsumerStatefulWidget {
  const BridgesBoard({super.key, required this.controller});
  final BridgesController controller;
  @override
  ConsumerState<BridgesBoard> createState() => _BridgesBoardState();
}

class _BridgesBoardState extends ConsumerState<BridgesBoard>
    with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// 0 → 1 once solved: the islets bounce one after another.
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final ValueNotifier<BridgesDrag?> _drag = ValueNotifier(null);
  final Map<String, TextPainter> _labels = {};
  bool _won = false;
  double _cell = 50;
  int? _dragFrom;
  BridgesController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_sync);
  }

  @override
  void didUpdateWidget(BridgesBoard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  /// The pulse only runs while something pulses; the win bounce starts once.
  void _sync() {
    if (!mounted) return;
    final still = MediaQuery.disableAnimationsOf(context);
    if (c.solved && !_won) {
      _won = true;
      still ? _win.value = 1 : _win.forward();
    }
    final want = !still && (c.spotlightIsland != null || c.hintLink != null);
    if (want && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!want && _anim.isAnimating) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    for (final t in _labels.values) {
      t.dispose();
    }
    _drag.dispose();
    _anim.dispose();
    _win.dispose();
    super.dispose();
  }

  Offset _centre(int i) {
    final isl = c.puzzle.islands[i];
    return Offset((isl.col + .5) * _cell, (isl.row + .5) * _cell);
  }

  /// The islet under [p] (within a touch-friendly radius), or null.
  int? _isletAt(Offset p) {
    int? best;
    var bestD = _cell * .6;
    for (var i = 0; i < c.puzzle.islands.length; i++) {
      final d = (_centre(i) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t =
        ((p - a).dx * ab.dx + (p - a).dy * ab.dy) /
        (ab.dx * ab.dx + ab.dy * ab.dy);
    final q = a + ab * t.clamp(0.0, 1.0);
    return (p - q).distance;
  }

  /// The pair whose gap (or existing bridge) [p] is on.
  (int, int)? _pairAt(Offset p) {
    (int, int)? best;
    var bestD = _cell * .42;
    for (final (a, b) in c.pairs) {
      final d = _distToSegment(p, _centre(a), _centre(b));
      if (d < bestD) {
        bestD = d;
        best = (a, b);
      }
    }
    return best;
  }

  /// The pair of [from] that a drag towards [to] points at.
  (int, int)? _pairFromDrag(int from, Offset to) {
    final start = _centre(from);
    final d = to - start;
    if (d.distance < _cell * .45) return null;
    (int, int)? best;
    var bestCos = .8;
    for (final (a, b) in c.pairs) {
      if (a != from && b != from) continue;
      final other = a == from ? b : a;
      final v = _centre(other) - start;
      final cos = (d.dx * v.dx + d.dy * v.dy) / (d.distance * v.distance);
      if (cos > bestCos) {
        bestCos = cos;
        best = (a, b);
      }
    }
    return best;
  }

  void _apply(int a, int b) {
    if (_won) return;
    final changed = c.cycle(a, b);
    final fb = ref.read(feedbackProvider);
    if (changed) {
      fb
        ..tick()
        ..play(Sfx.place, volume: .6);
      if (c.solved) fb.bump();
    } else {
      fb
        ..thud()
        ..play(Sfx.error, volume: .5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final st = context.island(GameId.bridges);
    final mark = ref.watch(settingsProvider.select((s) => s.markMistakes));
    final large = ref.watch(settingsProvider.select((s) => s.largeNumbers));
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth - 20, 360.0);
        _cell = side / c.puzzle.cols;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mi.card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(color: st.cardLedge, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => Semantics(
                    label:
                        'Bridges board, ${c.puzzle.rows} by ${c.puzzle.cols}. ${c.progressText}.',
                    child: GestureDetector(
                      // Start where the finger landed, not where the swipe was
                      // recognized.
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) {
                        _dragFrom = _won ? null : _isletAt(d.localPosition);
                      },
                      onPanUpdate: (d) {
                        final f = _dragFrom;
                        if (f == null) return;
                        _drag.value = BridgesDrag(f, d.localPosition);
                        if (!_anim.isAnimating &&
                            !MediaQuery.disableAnimationsOf(context)) {
                          _anim.repeat();
                        }
                      },
                      onPanEnd: (_) {
                        final f = _dragFrom, end = _drag.value?.to;
                        _dragFrom = null;
                        _drag.value = null;
                        _sync();
                        if (f == null || end == null) return;
                        final target = _isletAt(end);
                        (int, int)? pair;
                        if (target != null && target != f) {
                          final lo = min(f, target), hi = max(f, target);
                          pair = c.pairs.contains((lo, hi)) ? (lo, hi) : null;
                        }
                        pair ??= _pairFromDrag(f, end);
                        if (pair != null) _apply(pair.$1, pair.$2);
                      },
                      onPanCancel: () {
                        _dragFrom = null;
                        _drag.value = null;
                      },
                      onTapUp: (d) {
                        final pair = _pairAt(d.localPosition);
                        if (pair != null) _apply(pair.$1, pair.$2);
                      },
                      child: CustomPaint(
                        size: Size(side, _cell * c.puzzle.rows),
                        painter: BridgesPainter(
                          c,
                          st,
                          mi,
                          _anim,
                          _win,
                          _drag,
                          mark,
                          large,
                          _labels,
                          _semantics,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // One fixed-height slot: the legend, a blocked-tap message, or the nudge
            // when every number is right but the islets are not joined. The board
            // above never moves.
            SizedBox(
              height: 56,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  final Widget child;
                  if (c.message != null) {
                    child = MiBanner(
                      key: ValueKey(c.message),
                      text: c.message!,
                      onDismiss: c.dismissMessage,
                    );
                  } else if (c.numbersMetButSplit) {
                    child = const MiBanner(
                      key: ValueKey('split'),
                      tone: MiBannerTone.info,
                      text: 'Every number is right — now join all the islets into one group.',
                    );
                  } else {
                    child = const _LegendRow(key: ValueKey('legend'));
                  }
                  return AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: child,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Every possible bridge as a button for screen readers: "Bridge between the 3
  /// at row 1, column 2 and the 2 at row 1, column 5: one built".
  List<CustomPainterSemantics> _semantics(Size size) {
    final p = c.puzzle;
    final dir = Directionality.of(context);
    String place(int i) =>
        'the ${p.islands[i].need} at row ${p.islands[i].row + 1}, column ${p.islands[i].col + 1}';
    return [
      for (final (a, b) in c.pairs)
        CustomPainterSemantics(
          key: ValueKey((a, b)),
          rect: Rect.fromPoints(_centre(a), _centre(b)).inflate(_cell * .25),
          properties: SemanticsProperties(
            textDirection: dir,
            button: true,
            label:
                'Bridge between ${place(a)} and ${place(b)}: ${switch (c.bridgesBetween(a, b)) {
                  0 => 'none built',
                  1 => 'one built',
                  _ => 'two built',
                }}',
            onTap: () => _apply(a, b),
          ),
        ),
    ];
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({super.key});
  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    // One row that shrinks to fit (the slot above it is a fixed 56 pt, so a second
    // line at a large text size would spill out). No `alignment:` on the Container:
    // it would stretch the chip to whatever width it is offered.
    Widget chip(String text) => Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: mi.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: MiText.caption.copyWith(
            color: mi.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip('Tap a gap: 1 bridge'),
            const SizedBox(width: 6),
            chip('Again: 2'),
            const SizedBox(width: 6),
            chip('Again: remove'),
          ],
        ),
      ),
    );
  }
}
