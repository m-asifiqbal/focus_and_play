// Quilt: stitch the field into rectangle patches, one clue per patch.
//
// Drag from one square to another to stitch a patch (it replaces anything it
// overlaps); tap a patch to unpick it. The drag preview takes the clue's colour when
// it would be right; a patch that is wrong is hatched red and a message under the
// board says why, in words. Solving the grid merges the patches into one picture.

import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/game_id.dart';
import '../../games/quilt/quilt.dart';
import '../../state/save_controller.dart';
import 'quilt_controller.dart';
import 'quilt_painter.dart';

export 'quilt_controller.dart';

/// Plain-words reason a patch is wrong ("This patch must be a wide rectangle, not a
/// tall rectangle").
String quiltFaultText(QuiltFault f) {
  String shape(QuiltShape s) => switch (s) {
    QuiltShape.square => 'a square',
    QuiltShape.tall => 'a tall rectangle',
    QuiltShape.wide => 'a wide rectangle',
  };
  return switch (f.kind) {
    QuiltFaultKind.noClue =>
      'This patch has no clue. Every patch wraps exactly one clue.',
    QuiltFaultKind.manyClues =>
      'This patch holds ${f.clues} clues. Each patch holds exactly one — split it up.',
    QuiltFaultKind.wrongArea =>
      'This clue says ${f.needArea} squares, but this patch covers ${f.haveArea}.',
    QuiltFaultKind.wrongShape =>
      'This patch must be ${shape(f.needShape!)}, not ${shape(f.haveShape!)}.',
  };
}

class QuiltBoard extends ConsumerStatefulWidget {
  const QuiltBoard({super.key, required this.controller});
  final QuiltController controller;
  @override
  ConsumerState<QuiltBoard> createState() => _QuiltBoardState();
}

class _QuiltBoardState extends ConsumerState<QuiltBoard>
    with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// 0 → 1 once solved: the patches grow together into one picture.
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  final Map<String, TextPainter> _labels = {};
  bool _won = false;
  double _cell = 50;
  QuiltController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_sync);
  }

  @override
  void didUpdateWidget(QuiltBoard old) {
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

  /// The marching-ants preview, the hint pulse and the win merge only run while
  /// they have something to show, so an idle board doesn't repaint every frame.
  void _sync() {
    if (!mounted) return;
    final still = MediaQuery.disableAnimationsOf(context);
    if (c.solved && !_won) {
      _won = true;
      still ? _win.value = 1 : _win.forward();
    }
    final want =
        !still &&
        (c.preview != null || c.hintRect != null || c.spotlightClue != null);
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
    _anim.dispose();
    _win.dispose();
    super.dispose();
  }

  int _cellAt(Offset p) {
    final col = (p.dx / _cell).floor().clamp(0, c.n - 1),
        row = (p.dy / _cell).floor().clamp(0, c.n - 1);
    return row * c.n + col;
  }

  void _end() {
    if (_won) return;
    final r = c.endDrag();
    final fb = ref.read(feedbackProvider);
    if (r == 1) {
      // A wrong patch feels different from a right one (when mistakes are shown).
      if (c.fault != null && ref.read(settingsProvider).markMistakes) {
        fb
          ..thud()
          ..play(Sfx.error, volume: .6);
      } else {
        fb
          ..bump()
          ..play(Sfx.place, volume: .7);
      }
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
                      // Start where the finger landed, not where the swipe was recognised
                      // (a quick flick would otherwise begin on the wrong square).
                      dragStartBehavior: DragStartBehavior.down,
                      onPanStart: (d) =>
                          _won ? null : c.startDrag(_cellAt(d.localPosition)),
                      onPanUpdate: (d) =>
                          _won ? null : c.updateDrag(_cellAt(d.localPosition)),
                      onPanEnd: (_) => _end(),
                      onTapDown: (d) =>
                          _won ? null : c.startDrag(_cellAt(d.localPosition)),
                      onTapUp: (_) => _end(),
                      child: CustomPaint(
                        size: Size.square(side),
                        painter: QuiltPainter(
                          c,
                          st,
                          mi,
                          _anim,
                          _win,
                          mark,
                          cb,
                          large,
                          _labels,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // One fixed-height slot: the legend, or — when the last patch is wrong —
            // the reason why. The board above never moves.
            SizedBox(
              height: 56,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  final f = mark ? c.fault : null;
                  return AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: f == null
                        ? const _LegendRow(key: ValueKey('legend'))
                        : _FaultBanner(
                            key: ValueKey(f),
                            text: quiltFaultText(f),
                            onDismiss: c.dismissFault,
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "This patch must be a wide rectangle, not a tall rectangle" with a dismiss ✕.
class _FaultBanner extends StatelessWidget {
  const _FaultBanner({super.key, required this.text, required this.onDismiss});
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    // A live region announces the message; its children (text and the ✕ button)
    // stay reachable, so a screen reader can dismiss it.
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(mi.danger.withValues(alpha: .12), mi.card),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mi.danger.withValues(alpha: .6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: mi.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MiText.small.copyWith(color: mi.ink, height: 1.25),
              ),
            ),
            MiIconButton(
              icon: Icons.close_rounded,
              label: 'Dismiss message',
              background: Colors.transparent,
              onTap: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({super.key});

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    return Center(
      child: Wrap(
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
