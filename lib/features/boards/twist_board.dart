// Twist: trace hidden words through neighbouring letter tiles.
//
// Drag across tiles (or tap them one by one, then tap the last tile again to
// submit). Found words lock in their colour; hint letters glow in the sun
// colour.

import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../domain/game_id.dart';
import '../../games/twist/twist.dart';
import '../../state/save_controller.dart';
import '../play/board_controller.dart';
import 'drag_sampling.dart';

class TwistController extends BoardController {
  /// The first word (shortest first, as the slots list them) starts with its
  /// first letter showing, free — like every word after a find.
  TwistController(this.puzzle) {
    if (puzzle.words.isNotEmpty) {
      revealed[0] = 1;
      message = 'The first word starts with ${puzzle.words[0].word[0]}';
      messageGood = true;
    }
  }
  final TwistPuzzle puzzle;
  final Set<int> found = {};
  final List<int> foundOrder = [];
  final Map<int, int> revealed = {};
  List<int> traced = [];

  /// Short message after a submit ("Not one of the words", …); cleared on the
  /// next move.
  String? message;

  /// Whether [message] is good news (a found word) rather than a miss.
  bool messageGood = false;

  /// Found word → the word whose first letter that find revealed for free, so
  /// undoing the find takes the free letter back too.
  final Map<int, int> _freeReveal = {};

  @override
  bool get solved => TwistRules.isSolved(puzzle, found);
  @override
  bool get canHint => !solved;
  @override
  bool get canUndo => foundOrder.isNotEmpty || traced.isNotEmpty;
  @override
  String get resetLabel => 'Clear';
  @override
  String get progressText => '${found.length} of ${puzzle.words.length} words';

  String get tracedWord => traced.map((c) => puzzle.letters[c]).join();

  bool tap(int cell) {
    message = null;
    if (traced.isNotEmpty && traced.last == cell) return false;
    final i = traced.indexOf(cell);
    if (i >= 0) {
      traced = traced.sublist(0, i + 1);
      notifyListeners();
      return true;
    }
    if (TwistRules.canAppend(puzzle, traced, found, cell)) {
      traced = [...traced, cell];
      notifyListeners();
      return true;
    }
    if (!_inFound(cell)) {
      traced = [cell];
      notifyListeners();
      return true;
    }
    return false;
  }

  bool _inFound(int cell) =>
      found.any((w) => puzzle.words[w].cells.contains(cell));

  /// Ends a trace. Returns 1 for a found word, -1 for a miss, 0 for nothing.
  int submit() {
    if (traced.length < 2) {
      return 0;
    }
    final idx = TwistRules.match(puzzle, traced, found);
    if (idx != null) {
      found.add(idx);
      foundOrder.add(idx);
      traced = [];
      final next = _revealNextFirstLetter(idx);
      message = next == null
          ? null
          : 'Nice! The next word starts with ${puzzle.words[next].word[0]}';
      messageGood = true;
      notifyListeners();
      return 1;
    }
    messageGood = false;
    message = TwistRules.sameWordOtherCells(puzzle, traced, found) != null
        ? 'Right word — try other tiles'
        : (traced.length >= 4 ? '"$tracedWord" isn\'t one of the words' : null);
    traced = [];
    notifyListeners();
    return message == null ? 0 : -1;
  }

  /// After the player finds a word, the next unfound word (shortest first — the
  /// order the slots are listed in) that shows no letter yet gets its first
  /// letter for free. It is not a hint: no hint is spent, no star is lost.
  /// Returns that word's index, or null when every unfound word already shows
  /// one.
  int? _revealNextFirstLetter(int foundIdx) {
    for (var i = 0; i < puzzle.words.length; i++) {
      if (found.contains(i) || (revealed[i] ?? 0) > 0) continue;
      revealed[i] = 1;
      _freeReveal[foundIdx] = i;
      return i;
    }
    return null;
  }

  void _takeBackFreeLetter(int foundIdx) {
    final w = _freeReveal.remove(foundIdx);
    // Only when no hint has added letters to it since.
    if (w != null && revealed[w] == 1) revealed.remove(w);
  }

  @override
  HintNote? hint() {
    if (solved) return null;
    final h = TwistRules.hint(puzzle, found, revealed);
    revealed[h.wordIndex] = h.lettersShown;
    final w = puzzle.words[h.wordIndex];
    if (h.lettersShown >= w.word.length) {
      found.add(h.wordIndex);
      foundOrder.add(h.wordIndex);
      notifyListeners();
      return HintNote('Revealed "${w.word}".');
    }
    traced = [];
    notifyListeners();
    final start = w.word.substring(0, h.lettersShown);
    return HintNote(
      'A ${w.word.length}-letter word starts with $start — the glowing tiles.',
    );
  }

  @override
  void undo() {
    if (traced.isNotEmpty) {
      traced = [];
    } else if (foundOrder.isNotEmpty) {
      final w = foundOrder.removeLast();
      found.remove(w);
      _takeBackFreeLetter(w);
    }
    message = null;
    notifyListeners();
  }

  @override
  void reset() {
    for (final w in [..._freeReveal.keys]) {
      _takeBackFreeLetter(w);
    }
    found.clear();
    foundOrder.clear();
    traced = [];
    message = null;
    notifyListeners();
  }
}

class TwistBoard extends ConsumerStatefulWidget {
  const TwistBoard({super.key, required this.controller});
  final TwistController controller;
  @override
  ConsumerState<TwistBoard> createState() => _TwistBoardState();
}

class _TwistBoardState extends ConsumerState<TwistBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  double _cell = 56;
  static const _gap = 6.0;

  TwistController get c => widget.controller;

  Offset? _lastDrag;
  bool _wantGlow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncGlow();
  }

  /// The glow only runs while some tile shows hint letters (idle boards don't
  /// repaint every frame).
  void _syncGlow() {
    if (_wantGlow && !MediaQuery.disableAnimationsOf(context)) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else if (_glow.isAnimating) {
      _glow.stop();
    }
  }

  void _drag(Offset to) {
    final from = _lastDrag ?? to;
    _lastDrag = to;
    for (final p in pointsAlong(from, to, _cell / 4)) {
      _touch(_cellAt(p));
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  int? _cellAt(Offset p, {bool strict = true}) {
    final pitch = _cell + _gap;
    final col = (p.dx / pitch).floor(), row = (p.dy / pitch).floor();
    if (row < 0 || col < 0 || row >= c.puzzle.rows || col >= c.puzzle.cols) {
      return null;
    }
    if (strict) {
      final cx = col * pitch + _cell / 2, cy = row * pitch + _cell / 2;
      if ((Offset(cx, cy) - p).distance > _cell * .42) return null;
    }
    return row * c.puzzle.cols + col;
  }

  void _touch(int? cell) {
    if (cell == null) return;
    if (c.tap(cell)) {
      ref.read(feedbackProvider)
        ..tick()
        ..play(Sfx.step, volume: .5);
    }
  }

  void _submit() {
    final r = c.submit();
    final fb = ref.read(feedbackProvider);
    if (r == 1) {
      fb
        ..bump()
        ..play(Sfx.word);
    } else if (r == -1) {
      fb
        ..thud()
        ..play(Sfx.error, volume: .6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final st = context.island(GameId.twist);
    final large = ref.watch(settingsProvider.select((s) => s.largeNumbers));
    final colourBlind = ref.watch(
      settingsProvider.select((s) => s.colourBlind),
    );
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.puzzle;
        final hintCells = <int, bool>{};
        for (final e in c.revealed.entries) {
          if (c.found.contains(e.key)) continue;
          for (final cell in p.words[e.key].cells.take(e.value)) {
            hintCells[cell] = true;
          }
        }
        final wordOf = <int, int>{};
        for (final w in c.found) {
          for (final cell in p.words[w].cells) {
            wordOf[cell] = w;
          }
        }
        if (_wantGlow != hintCells.isNotEmpty) {
          _wantGlow = hintCells.isNotEmpty;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncGlow();
          });
        }
        return LayoutBuilder(
          builder: (context, box) {
            _cell = min(
              64.0,
              (min(box.maxWidth, 360.0) - 24 - _gap * (p.cols - 1)) / p.cols,
            );
            final w = _cell * p.cols + _gap * (p.cols - 1);
            final h = _cell * p.rows + _gap * (p.rows - 1);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Theme: ${p.theme}',
                  style: MiText.label.copyWith(
                    color: st.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: c.traced.isEmpty
                        ? Text(
                            c.message ?? 'Drag across neighbouring tiles',
                            key: ValueKey(c.message),
                            style: MiText.small.copyWith(
                              color: c.message == null
                                  ? mi.inkSoft
                                  : (c.messageGood ? st.ink : mi.danger),
                              fontWeight: c.messageGood && c.message != null
                                  ? FontWeight.w800
                                  : null,
                            ),
                          )
                        : Container(
                            key: const ValueKey('word'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: mi.isNight ? mi.sunk : mi.navy,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              c.tracedWord,
                              style: MiText.headline.copyWith(
                                color: const Color(0xFFFFC233),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mi.card,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: st.cardLedge,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Semantics(
                      label:
                          'Twist board, ${p.rows} by ${p.cols} letters. '
                          '${c.progressText}.',
                      child: GestureDetector(
                        // Start where the finger landed, not where the swipe was
                        // recognized (a quick flick would otherwise begin on
                        // the wrong square).
                        dragStartBehavior: DragStartBehavior.down,
                        onPanStart: (d) {
                          _lastDrag = d.localPosition;
                          _touch(_cellAt(d.localPosition, strict: false));
                        },
                        onPanUpdate: (d) => _drag(d.localPosition),
                        onPanEnd: (_) {
                          _lastDrag = null;
                          _submit();
                        },
                        onTapUp: (d) {
                          final cell = _cellAt(d.localPosition, strict: false);
                          if (cell != null &&
                              c.traced.isNotEmpty &&
                              c.traced.last == cell) {
                            _submit();
                          } else {
                            _touch(cell);
                          }
                        },
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TwistLines(
                                    c,
                                    _cell,
                                    _gap,
                                    st,
                                    wordOf,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < p.letters.length; i++)
                                Positioned(
                                  left: (i % p.cols) * (_cell + _gap),
                                  top: (i ~/ p.cols) * (_cell + _gap),
                                  width: _cell,
                                  height: _cell,
                                  child: _tile(
                                    i,
                                    wordOf,
                                    hintCells,
                                    st,
                                    mi,
                                    large,
                                    colourBlind,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _WordSlots(controller: c, style: st),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tile(
    int i,
    Map<int, int> wordOf,
    Map<int, bool> hintCells,
    IslandStyle st,
    MiColors mi,
    bool large,
    bool colourBlind,
  ) {
    final traced = c.traced.contains(i);
    final w = wordOf[i];
    final Color bg;
    Color fg = mi.ink;
    if (w != null) {
      bg = w.isEven ? st.color : st.ledge;
      fg = Colors.white;
    } else if (traced) {
      bg = const Color(0xFFFFC233);
      fg = const Color(0xFF13213C);
    } else {
      bg = mi.isNight ? st.cell : Colors.white;
    }
    final hinted = hintCells[i] ?? false;
    final letter = Stack(
      alignment: Alignment.center,
      children: [
        Text(
          c.puzzle.letters[i],
          style: MiText.title.copyWith(
            fontSize: _cell * (large ? .55 : .46),
            color: fg,
          ),
        ),
        if (colourBlind && w != null && w.isOdd)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    Widget box(Color border, double width) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_cell * .25),
        border: Border.all(color: border, width: width),
      ),
      child: letter,
    );
    // Only glowing (hinted) tiles listen to the glow animation; the rest are
    // static.
    final tile = hinted
        ? AnimatedBuilder(
            animation: _glow,
            builder: (context, _) =>
                box(Color.lerp(mi.sun, mi.sunLedge, _glow.value)!, 3.5),
          )
        : box(
            w == null && !traced
                ? (mi.isNight ? st.cellEdge : st.cardLedge)
                : Colors.transparent,
            2,
          );
    return AnimatedScale(
      scale: traced ? 1.06 : 1,
      duration: const Duration(milliseconds: 120),
      child: tile,
    );
  }
}

class _TwistLines extends CustomPainter {
  _TwistLines(this.c, this.cell, this.gap, this.st, this.wordOf);
  final TwistController c;
  final double cell, gap;
  final IslandStyle st;
  final Map<int, int> wordOf;

  Offset _ctr(int i) => Offset(
    (i % c.puzzle.cols) * (cell + gap) + cell / 2,
    (i ~/ c.puzzle.cols) * (cell + gap) + cell / 2,
  );

  void _line(Canvas canvas, List<int> cells, Color col) {
    if (cells.length < 2) return;
    final p = Path()..moveTo(_ctr(cells.first).dx, _ctr(cells.first).dy);
    for (final cc in cells.skip(1)) {
      p.lineTo(_ctr(cc).dx, _ctr(cc).dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .36
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in c.found) {
      _line(canvas, c.puzzle.words[w].cells, w.isEven ? st.color : st.ledge);
    }
    _line(canvas, c.traced, const Color(0xFFFFC233));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WordSlots extends StatelessWidget {
  const _WordSlots({required this.controller, required this.style});
  final TwistController controller;
  final IslandStyle style;

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final p = controller.puzzle;
    return Semantics(
      label: '${controller.found.length} of ${p.words.length} words found',
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < p.words.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < p.words[i].word.length; k++)
                  Container(
                    width: 22,
                    height: 24,
                    margin: const EdgeInsets.only(right: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: controller.found.contains(i)
                          ? (i.isEven ? style.color : style.ledge)
                          : (k < (controller.revealed[i] ?? 0)
                                ? mi.sunTint
                                : (mi.isNight ? style.cell : Colors.white)),
                      borderRadius: BorderRadius.circular(6),
                      border: controller.found.contains(i)
                          ? null
                          : Border.all(
                              color: mi.isNight
                                  ? style.cellEdge
                                  : style.cardLedge,
                              width: 2,
                            ),
                    ),
                    child:
                        (controller.found.contains(i) ||
                            k < (controller.revealed[i] ?? 0))
                        ? Text(
                            p.words[i].word[k],
                            style: MiText.small.copyWith(
                              fontFamily: MiFonts.display,
                              color: controller.found.contains(i)
                                  ? Colors.white
                                  : mi.sunInk,
                            ),
                          )
                        : null,
                  ),
                if (controller.found.contains(i))
                  Icon(Icons.check_rounded, size: 18, color: mi.brandInk),
              ],
            ),
        ],
      ),
    );
  }
}
