// Thread: one path through every square, passing the numbers in order.
//
// Drag from 1; dragging back over the thread rewinds it; fast drags along a row
// or column fill the squares in between. Hints rewind to the last correct square
// and light the next few squares in sun yellow.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../domain/game_id.dart';
import '../../games/thread/thread.dart';
import '../../state/save_controller.dart';
import '../play/board_controller.dart';

class ThreadController extends BoardController {
  ThreadController(this.puzzle);
  final ThreadPuzzle puzzle;
  List<int> path = [];
  List<int> hintCells = [];
  final List<List<int>> _history = [];
  List<int>? _strokeStart;

  int get n => puzzle.size;

  @override
  bool get solved => ThreadRules.isSolved(puzzle, path);
  @override
  bool get canHint => !solved;
  @override
  bool get canUndo => _history.isNotEmpty;
  @override
  String get progressText => '${path.length} of ${puzzle.cellCount} squares';

  void beginStroke() => _strokeStart = List.of(path);

  void endStroke() {
    final s = _strokeStart;
    if (s != null && !_same(s, path)) _history.add(s);
    _strokeStart = null;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Moves the thread's head to [cell]: start, extend, fill a straight run, or rewind.
  /// Returns how many squares were added (negative when rewound, 0 for no change).
  int moveTo(int cell) {
    if (path.isEmpty) {
      if (puzzle.numbers[cell] == 1) {
        path = [cell];
        hintCells = [];
        notifyListeners();
        return 1;
      }
      return 0;
    }
    final at = path.indexOf(cell);
    if (at >= 0) {
      if (at == path.length - 1) return 0;
      final removed = path.length - 1 - at;
      path = path.sublist(0, at + 1);
      notifyListeners();
      return -removed;
    }
    final head = path.last;
    final hr = head ~/ n, hc = head % n, r = cell ~/ n, c = cell % n;
    final steps = <int>[];
    if (hr == r && hc != c) {
      for (var k = hc + (c > hc ? 1 : -1); k != c + (c > hc ? 1 : -1); k += c > hc ? 1 : -1) {
        steps.add(r * n + k);
      }
    } else if (hc == c && hr != r) {
      for (var k = hr + (r > hr ? 1 : -1); k != r + (r > hr ? 1 : -1); k += r > hr ? 1 : -1) {
        steps.add(k * n + c);
      }
    } else {
      return 0;
    }
    final next = List.of(path);
    for (final s in steps) {
      if (!ThreadRules.canAppend(puzzle, next, s)) break;
      next.add(s);
    }
    if (next.length == path.length) return 0;
    final added = next.length - path.length;
    path = next;
    hintCells.removeWhere(path.contains);
    notifyListeners();
    return added;
  }

  @override
  HintNote? hint() {
    if (solved) return null;
    final h = ThreadRules.hint(puzzle, path, reveal: 3);
    _history.add(List.of(path));
    path = path.sublist(0, min(h.keepLength, path.length));
    if (path.isEmpty) path = [puzzle.cellOf(1)!];
    hintCells = h.next.where((c) => !path.contains(c)).toList();
    notifyListeners();
    return const HintNote('Follow the glowing squares from the end of your thread.');
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    path = _history.removeLast();
    notifyListeners();
  }

  @override
  void reset() {
    if (path.isNotEmpty) _history.add(List.of(path));
    path = [];
    hintCells = [];
    notifyListeners();
  }
}

class ThreadBoard extends ConsumerStatefulWidget {
  const ThreadBoard({super.key, required this.controller});
  final ThreadController controller;
  @override
  ConsumerState<ThreadBoard> createState() => _ThreadBoardState();
}

class _ThreadBoardState extends ConsumerState<ThreadBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  double _cell = 52;
  ThreadController get c => widget.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _pulse.stop() : _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int? _cellAt(Offset p, {bool strict = true}) {
    final col = (p.dx / _cell).floor(), row = (p.dy / _cell).floor();
    if (row < 0 || col < 0 || row >= c.n || col >= c.n) return null;
    if (strict) {
      final ctr = Offset(col * _cell + _cell / 2, row * _cell + _cell / 2);
      if ((ctr - p).distance > _cell * .48) return null;
    }
    return row * c.n + col;
  }

  void _move(int? cell) {
    if (cell == null) return;
    final d = c.moveTo(cell);
    if (d == 0) return;
    final fb = ref.read(feedbackProvider);
    fb.tick();
    if (d > 0) fb.play(Sfx.step, volume: .45);
  }

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final st = context.island(GameId.thread);
    final large = ref.watch(settingsProvider.select((s) => s.largeNumbers));
    return LayoutBuilder(builder: (context, box) {
      final side = min(box.maxWidth - 20, 360.0);
      _cell = side / c.n;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: mi.card, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: st.cardLedge, offset: const Offset(0, 4))]),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Semantics(
            label: 'Thread board, ${c.n} by ${c.n}. ${c.progressText}. Next number ${ThreadRules.nextNumber(c.puzzle, c.path)}.',
            child: GestureDetector(
              onPanStart: (d) {
                c.beginStroke();
                _move(_cellAt(d.localPosition, strict: false));
              },
              onPanUpdate: (d) => _move(_cellAt(d.localPosition)),
              onPanEnd: (_) => c.endStroke(),
              onTapUp: (d) {
                c.beginStroke();
                _move(_cellAt(d.localPosition, strict: false));
                c.endStroke();
              },
              child: CustomPaint(size: Size.square(side), painter: _ThreadPainter(c, st, mi, _pulse, large)),
            ),
          ),
        ),
      );
    });
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter(this.c, this.st, this.mi, this.pulse, this.large) : super(repaint: pulse);
  final ThreadController c;
  final IslandStyle st;
  final MiColors mi;
  final Animation<double> pulse;
  final bool large;

  @override
  void paint(Canvas canvas, Size size) {
    final n = c.n;
    final cell = size.width / n;
    Offset ctr(int i) => Offset((i % n) * cell + cell / 2, (i ~/ n) * cell + cell / 2);
    final onPath = c.path.toSet();
    for (var i = 0; i < n * n; i++) {
      final r = Rect.fromLTWH((i % n) * cell + 2, (i ~/ n) * cell + 2, cell - 4, cell - 4);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * .2)), Paint()..color = c.hintCells.contains(i) ? const Color(0xFFFFE29A) : (onPath.contains(i) ? Color.lerp(st.tint, st.color, .22)! : st.tint));
    }
    if (c.hintCells.isNotEmpty && c.path.isNotEmpty) {
      final hp = Path()..moveTo(ctr(c.path.last).dx, ctr(c.path.last).dy);
      for (final h in c.hintCells) {
        hp.lineTo(ctr(h).dx, ctr(h).dy);
      }
      final dash = Paint()
        ..color = const Color(0xFFDB9A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(4, cell * .14)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final m in hp.computeMetrics()) {
        final off = pulse.value * 24;
        for (var d = -24 + off; d < m.length; d += 24) {
          canvas.drawPath(m.extractPath(max(0, d), max(0, d + 12)), dash);
        }
      }
    }
    if (c.path.isNotEmpty) {
      final p = Path()..moveTo(ctr(c.path.first).dx, ctr(c.path.first).dy);
      for (final i in c.path.skip(1)) {
        p.lineTo(ctr(i).dx, ctr(i).dy);
      }
      canvas.drawPath(p, Paint()
        ..color = st.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(p, Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
      if (!c.solved) {
        final head = ctr(c.path.last);
        final t = pulse.value;
        canvas.drawCircle(head, cell * (.34 + .3 * t), Paint()..color = st.color.withValues(alpha: .45 * (1 - t)));
        canvas.drawCircle(head, cell * .32, Paint()..color = st.color);
        canvas.drawCircle(head, cell * .32, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      }
    }
    final next = ThreadRules.nextNumber(c.puzzle, c.path);
    for (final e in c.puzzle.numbers.entries) {
      final at = ctr(e.key);
      final isNext = e.value == next && !c.solved;
      final r = cell * (isNext ? .36 : .32);
      canvas.drawCircle(at, r, Paint()..color = const Color(0xFF13213C));
      canvas.drawCircle(at, r, Paint()
        ..color = isNext ? const Color(0xFFFFC233) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isNext ? 4 : 2.5);
      final tp = TextPainter(
        text: TextSpan(text: '${e.value}', style: TextStyle(fontFamily: MiFonts.display, fontWeight: FontWeight.w600, fontSize: cell * (large ? .42 : .36), color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
