// Quilt: stitch the field into rectangle patches, one clue per patch.
//
// Drag from one square to another to stitch a patch (it replaces anything it
// overlaps); tap a patch to unpick it. Patches that fit their clue get a fabric
// colour; ones that don't are shown grey with a warning edge.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../domain/game_id.dart';
import '../../games/quilt/quilt.dart';
import '../../state/save_controller.dart';
import '../play/board_controller.dart';

const _fabrics = [
  Color(0xFF9ED9B0),
  Color(0xFFFFD68A),
  Color(0xFFA9D3F5),
  Color(0xFFF7B6C2),
  Color(0xFFC9B8F5),
  Color(0xFFFFC2A1),
  Color(0xFFB6E3D4),
  Color(0xFFF2E394),
];

class QuiltController extends BoardController {
  QuiltController(this.puzzle);
  final QuiltPuzzle puzzle;
  List<QuiltRect> placed = [];
  final List<List<QuiltRect>> _history = [];
  int? dragFrom, dragTo;
  QuiltRect? hintRect;

  int get n => puzzle.size;
  QuiltRect? get preview => dragFrom == null || dragTo == null
      ? null
      : QuiltRect.spanning(dragFrom!, dragTo!, n);

  @override
  bool get solved => QuiltRules.isSolved(puzzle, placed);
  @override
  // A hint exists until every solution patch is placed, and placing all of them
  // is exactly "solved" (patches never overlap). Checked on every drag frame, so
  // keep it cheap: no candidate search here.
  bool get canHint => !solved;
  @override
  bool get canUndo => _history.isNotEmpty;
  @override
  String get progressText =>
      '${placed.where((r) => QuiltRules.fits(puzzle, r)).length} of ${puzzle.clues.length} patches';

  void startDrag(int cell) {
    dragFrom = cell;
    dragTo = cell;
    hintRect = null;
    notifyListeners();
  }

  void updateDrag(int cell) {
    if (dragFrom == null || cell == dragTo) return;
    dragTo = cell;
    notifyListeners();
  }

  /// Finishes a drag. Returns 1 when a patch was stitched, -1 when one was unpicked, 0 otherwise.
  int endDrag() {
    final r = preview;
    dragFrom = dragTo = null;
    if (r == null) {
      notifyListeners();
      return 0;
    }
    if (r.area == 1) {
      final hit = placed.indexWhere((p) => p.contains(r.row * n + r.col, n));
      if (hit >= 0) {
        _history.add(List.of(placed));
        placed = [...placed]..removeAt(hit);
        notifyListeners();
        return -1;
      }
      // A tap on an empty square: every patch is at least 2 squares, so a 1×1
      // patch could never fit. Ignore it instead of stitching a warning patch.
      notifyListeners();
      return 0;
    }
    _history.add(List.of(placed));
    placed = [...placed.where((p) => !p.overlaps(r)), r];
    notifyListeners();
    return 1;
  }

  @override
  HintNote? hint() {
    final h = QuiltRules.hint(puzzle, placed);
    if (h == null) return null;
    _history.add(List.of(placed));
    placed = [...placed.where((p) => !p.overlaps(h)), h];
    hintRect = h;
    notifyListeners();
    return HintNote(
      'Stitched a ${h.width} × ${h.height} patch for you — it glows on the board.',
    );
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    placed = _history.removeLast();
    hintRect = null;
    notifyListeners();
  }

  @override
  void reset() {
    if (placed.isNotEmpty) _history.add(List.of(placed));
    placed = [];
    hintRect = null;
    notifyListeners();
  }
}

class QuiltBoard extends ConsumerStatefulWidget {
  const QuiltBoard({super.key, required this.controller});
  final QuiltController controller;
  @override
  ConsumerState<QuiltBoard> createState() => _QuiltBoardState();
}

class _QuiltBoardState extends ConsumerState<QuiltBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  double _cell = 50;
  QuiltController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_syncAnim);
  }

  @override
  void didUpdateWidget(QuiltBoard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_syncAnim);
      widget.controller.addListener(_syncAnim);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnim();
  }

  /// The marching-ants preview and the hint pulse only run while visible, so an
  /// idle board doesn't repaint every frame.
  void _syncAnim() {
    if (!mounted) return;
    final want =
        !MediaQuery.disableAnimationsOf(context) &&
        (c.preview != null || c.hintRect != null);
    if (want && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!want && _anim.isAnimating) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    c.removeListener(_syncAnim);
    _anim.dispose();
    super.dispose();
  }

  int? _cellAt(Offset p) {
    final col = (p.dx / _cell).floor().clamp(0, c.n - 1),
        row = (p.dy / _cell).floor().clamp(0, c.n - 1);
    return row * c.n + col;
  }

  void _end() {
    final r = c.endDrag();
    final fb = ref.read(feedbackProvider);
    if (r == 1) {
      fb
        ..bump()
        ..play(Sfx.place, volume: .7);
    } else if (r == -1) {
      fb.tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final st = context.island(GameId.quilt);
    final mark = ref.watch(settingsProvider.select((s) => s.markMistakes));
    final cb = ref.watch(settingsProvider.select((s) => s.colourBlind));
    final large = ref.watch(settingsProvider.select((s) => s.largeNumbers));
    return LayoutBuilder(
      builder: (context, box) {
        final side = min(box.maxWidth - 20, 360.0);
        _cell = side / c.n;
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
                    label: 'Quilt board, ${c.n} by ${c.n}. ${c.progressText}.',
                    child: GestureDetector(
                      onPanStart: (d) => c.startDrag(_cellAt(d.localPosition)!),
                      onPanUpdate: (d) =>
                          c.updateDrag(_cellAt(d.localPosition)!),
                      onPanEnd: (_) => _end(),
                      onTapDown: (d) => c.startDrag(_cellAt(d.localPosition)!),
                      onTapUp: (_) => _end(),
                      child: CustomPaint(
                        size: Size.square(side),
                        painter: _QuiltPainter(
                          c,
                          st,
                          mi,
                          _anim,
                          mark,
                          cb,
                          large,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _Legend(
                  label: 'Size',
                  child: Text(
                    '4',
                    style: MiText.small.copyWith(
                      fontFamily: MiFonts.display,
                      color: mi.ink,
                    ),
                  ),
                ),
                _Legend(
                  label: 'Square',
                  child: _ShapeIcon(QuiltShape.square, mi.ink, 14),
                ),
                _Legend(
                  label: 'Tall',
                  child: _ShapeIcon(QuiltShape.tall, mi.ink, 14),
                ),
                _Legend(
                  label: 'Wide',
                  child: _ShapeIcon(QuiltShape.wide, mi.ink, 14),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.child, required this.label});
  final Widget child;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: context.mi.card,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(width: 6),
        Text(
          label,
          style: MiText.caption.copyWith(
            color: context.mi.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ShapeIcon extends StatelessWidget {
  const _ShapeIcon(this.shape, this.color, this.size);
  final QuiltShape shape;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ShapePainter(shape, color),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);
  final QuiltShape shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) => drawShapeGlyph(
    canvas,
    Offset(s.width / 2, s.height / 2),
    s.width,
    shape,
    color,
  );
  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shape != shape || old.color != color;
}

void drawShapeGlyph(
  Canvas canvas,
  Offset at,
  double size,
  QuiltShape shape,
  Color color,
) {
  // Solid bars, so a tall shape can't be mistaken for a 0.
  final (w, h) = switch (shape) {
    QuiltShape.square => (size * .72, size * .72),
    QuiltShape.tall => (size * .42, size * .95),
    QuiltShape.wide => (size * .95, size * .42),
  };
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: w, height: h),
      Radius.circular(size * .12),
    ),
    Paint()..color = color,
  );
}

class _QuiltPainter extends CustomPainter {
  _QuiltPainter(
    this.c,
    this.st,
    this.mi,
    this.anim,
    this.mark,
    this.colourBlind,
    this.large,
  ) : super(repaint: anim);
  final QuiltController c;
  final IslandStyle st;
  final MiColors mi;
  final Animation<double> anim;
  final bool mark, colourBlind, large;

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.n;
    final cell = size.width / n;
    Rect rectOf(QuiltRect r, [double inset = 3]) => Rect.fromLTWH(
      r.col * cell + inset,
      r.row * cell + inset,
      r.width * cell - inset * 2,
      r.height * cell - inset * 2,
    );
    for (var i = 0; i < n * n; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (i % n) * cell + 2,
            (i ~/ n) * cell + 2,
            cell - 4,
            cell - 4,
          ),
          Radius.circular(cell * .2),
        ),
        Paint()..color = st.tint,
      );
    }
    for (final r in c.placed) {
      final clue = QuiltRules.clueIn(c.puzzle, r);
      final fits = QuiltRules.fits(c.puzzle, r);
      final base = fits && clue != null
          ? _fabrics[clue % _fabrics.length]
          : (mi.isNight ? const Color(0xFF3A4A68) : const Color(0xFFD9DEE5));
      final rr = RRect.fromRectAndRadius(
        rectOf(r),
        Radius.circular(cell * .22),
      );
      canvas.drawRRect(rr, Paint()..color = base);
      if (colourBlind && fits && clue != null) {
        canvas.save();
        canvas.clipRRect(rr);
        final hatch = Paint()
          ..color = Colors.white.withValues(alpha: .45)
          ..strokeWidth = 2;
        final step = 8.0 + (clue % 3) * 4;
        for (var x = rr.left - rr.height; x < rr.right; x += step) {
          if (clue % 2 == 0) {
            canvas.drawLine(
              Offset(x, rr.bottom),
              Offset(x + rr.height, rr.top),
              hatch,
            );
          } else {
            canvas.drawLine(
              Offset(x, rr.top),
              Offset(x + rr.height, rr.bottom),
              hatch,
            );
          }
        }
        canvas.restore();
      }
      _dashedRect(
        canvas,
        rectOf(r, 8),
        cell * .14,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (mark && !fits) {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = mi.danger
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      if (c.hintRect == r) {
        final t = (sin(anim.value * 2 * pi) + 1) / 2;
        canvas.drawRRect(
          rr.inflate(2 + t * 3),
          Paint()
            ..color = const Color(0xFFFFC233)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }
    final pv = c.preview;
    if (pv != null) {
      final rr = RRect.fromRectAndRadius(
        rectOf(pv),
        Radius.circular(cell * .22),
      );
      canvas.drawRRect(rr, Paint()..color = st.color.withValues(alpha: .28));
      final metrics = (Path()..addRRect(rr)).computeMetrics();
      final dash = Paint()
        ..color = st.ledge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final m in metrics) {
        for (var d = -20 + anim.value * 20; d < m.length; d += 20) {
          canvas.drawPath(m.extractPath(max(0, d), max(0, d + 10)), dash);
        }
      }
    }
    for (final clue in c.puzzle.clues) {
      final at = Offset(
        (clue.cell % n) * cell + cell / 2,
        (clue.cell ~/ n) * cell + cell / 2,
      );
      final label = clue.area?.toString();
      final hasShape = clue.shape != null;
      final w = hasShape && label != null ? cell * .78 : cell * .58;
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: w, height: cell * .56),
        Radius.circular(cell * .28),
      );
      canvas.drawRRect(pill, Paint()..color = Colors.white);
      final unplaced = !c.placed.any((r) => r.contains(clue.cell, n));
      if (unplaced) {
        canvas.drawRRect(
          pill,
          Paint()
            ..color = st.cardLedge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      var x = at.dx;
      if (hasShape && label != null) x -= cell * .16;
      if (hasShape) {
        drawShapeGlyph(
          canvas,
          Offset(label != null ? x : at.dx, at.dy),
          cell * .26,
          clue.shape!,
          const Color(0xFF13213C),
        );
      }
      if (label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: MiFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: cell * (large ? .42 : .34),
              color: const Color(0xFF13213C),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final cx = hasShape ? at.dx + cell * .17 : at.dx;
        tp.paint(canvas, Offset(cx - tp.width / 2, at.dy - tp.height / 2));
      }
    }
    if (pv != null && pv.area > 1) {
      final txt = '${pv.width} × ${pv.height} = ${pv.area}';
      final tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: const TextStyle(
            fontFamily: MiFonts.body,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = rectOf(pv);
      final box = Rect.fromCenter(
        center: Offset(r.center.dx, max(14, r.top - 16)),
        width: tp.width + 16,
        height: 24,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(12)),
        Paint()..color = const Color(0xFF13213C),
      );
      tp.paint(
        canvas,
        Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2),
      );
    }
  }

  void _dashedRect(Canvas canvas, Rect r, double radius, Paint p) {
    for (final m
        in (Path()
              ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))))
            .computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, min(m.length, d + 5)), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
