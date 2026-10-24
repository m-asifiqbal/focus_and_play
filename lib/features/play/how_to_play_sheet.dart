// How to play each game: a small animated demo board and three steps.
// Shown automatically the first time a game is opened, and from level sheets.

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../domain/game_id.dart';

List<String> howToSteps(GameId g) => switch (g) {
  GameId.thread => [
    'Drag from 1 to start your thread.',
    'Pass the numbers in order — 1, 2, 3 and on.',
    'Fill every square to finish. Slide back along the thread to undo.',
  ],
  GameId.quilt => [
    'Drag across squares to stitch a rectangle patch.',
    'Each patch holds exactly one clue: its size, or its shape (square, tall or wide).',
    'Cover the whole field. Tap a patch to unpick it. A wrong patch turns red and tells you why.',
  ],
  GameId.twist => [
    'Drag across neighbouring tiles to spell a word.',
    'Every hidden word fits the theme, and every tile is used once.',
    'The slots show how long each word is. The first word\'s first letter is lit, and every word you find lights up the next one\'s.',
  ],
  GameId.sudoku => [
    'Tap a square, then tap a number.',
    'Each row, each column and each 2 × 3 box holds 1 to 6 exactly once.',
    'Turn on Notes to pencil in ideas.',
  ],
};

Future<void> showHowToPlay(BuildContext context, GameId game) =>
    showMiSheet<void>(context, builder: (_) => HowToPlaySheet(game: game));

class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key, required this.game});
  final GameId game;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final st = context.island(game);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${game.island.toUpperCase()} · HOW TO PLAY',
            style: MiText.overline.copyWith(color: st.ink),
          ),
          const SizedBox(height: 4),
          Text(game.title, style: MiText.display.copyWith(color: c.ink)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: st.tint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _Demo(game: game, size: 168),
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, step) in howToSteps(game).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: st.color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: MiText.headline.copyWith(
                        fontSize: 16,
                        color: st.onColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        step,
                        style: MiText.label.copyWith(
                          color: c.ink,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          MiButton(
            label: "Got it — let's play",
            color: st.color,
            ledge: st.ledge,
            onColor: st.onColor,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Looping demo of each game's core move.
class _Demo extends StatefulWidget {
  const _Demo({required this.game, required this.size});
  final GameId game;
  final double size;
  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = .8;
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _DemoPainter(
        widget.game,
        _c,
        IslandStyle.of(widget.game, context.mi),
      ),
    ),
  );
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.game, this.t, this.st) : super(repaint: t);
  final GameId game;
  final Animation<double> t;
  final IslandStyle st;

  @override
  void paint(Canvas canvas, Size size) {
    final n = game == GameId.sudoku ? 4 : 3;
    final cell = size.width / n;
    final p = min(1.0, t.value / .75);
    Offset ctr(int i) =>
        Offset((i % n) * cell + cell / 2, (i ~/ n) * cell + cell / 2);
    for (var i = 0; i < n * n; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (i % n) * cell + 3,
            (i ~/ n) * cell + 3,
            cell - 6,
            cell - 6,
          ),
          const Radius.circular(12),
        ),
        Paint()..color = Colors.white,
      );
    }
    final ink = Paint()..color = const Color(0xFF13213C);
    TextPainter label(String s, Color c, double fs) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: MiFonts.display,
          fontSize: fs,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    void text(String s, Offset at, Color c, double fs) {
      final tp = label(s, c, fs);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    switch (game) {
      case GameId.thread:
        const order = [0, 1, 2, 5, 4, 3, 6, 7, 8];
        final k = p * (order.length - 1);
        final path = Path()..moveTo(ctr(0).dx, ctr(0).dy);
        for (var i = 1; i <= k.floor(); i++) {
          path.lineTo(ctr(order[i]).dx, ctr(order[i]).dy);
        }
        if (k.floor() < order.length - 1) {
          final a = ctr(order[k.floor()]), b = ctr(order[k.floor() + 1]);
          final q = Offset.lerp(a, b, k - k.floor())!;
          path.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = st.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * .42
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        for (final (i, num) in [(0, '1'), (3, '2'), (8, '3')]) {
          canvas.drawCircle(ctr(i), cell * .24, ink);
          text(num, ctr(i), Colors.white, cell * .26);
        }
      case GameId.quilt:
        final cols = [0xFF9ED9B0, 0xFFFFD68A, 0xFFA9D3F5];
        final rects = [
          const Rect.fromLTWH(0, 0, 2, 1),
          const Rect.fromLTWH(2, 0, 1, 3),
          const Rect.fromLTWH(0, 1, 2, 2),
        ];
        for (var i = 0; i < 3; i++) {
          final shown = (p * 3 - i).clamp(0.0, 1.0);
          if (shown <= 0) continue;
          final r = rects[i];
          final full = Rect.fromLTWH(
            r.left * cell + 4,
            r.top * cell + 4,
            r.width * cell - 8,
            r.height * cell - 8,
          );
          final grow = Rect.fromLTWH(
            full.left,
            full.top,
            full.width * shown,
            full.height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(grow, const Radius.circular(12)),
            Paint()..color = Color(cols[i]),
          );
        }
        for (final (c, s) in [(0, '2'), (5, '3'), (6, '4')]) {
          canvas.drawCircle(ctr(c), cell * .22, Paint()..color = Colors.white);
          text(s, ctr(c), const Color(0xFF13213C), cell * .24);
        }
      case GameId.twist:
        const letters = ['S', 'U', 'N', 'E', 'T', 'P', 'N', 'A', 'L'];
        const word = [0, 1, 2];
        const word2 = [5, 8, 7, 6, 3, 4];
        for (var i = 0; i < 9; i++) {
          final inA = word.indexOf(i), inB = word2.indexOf(i);
          final lit =
              (inA >= 0 && p * 9 > inA) || (inB >= 0 && p * 9 > 3 + inB);
          if (lit) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  (i % 3) * cell + 3,
                  (i ~/ 3) * cell + 3,
                  cell - 6,
                  cell - 6,
                ),
                const Radius.circular(12),
              ),
              Paint()..color = inA >= 0 ? st.color : const Color(0xFFFFC233),
            );
          }
          text(
            letters[i],
            ctr(i),
            lit && inA >= 0 ? Colors.white : const Color(0xFF13213C),
            cell * .4,
          );
        }
      case GameId.sudoku:
        const grid = [1, 0, 3, 4, 3, 4, 0, 2, 2, 0, 4, 3, 4, 3, 2, 0];
        const answer = {1: 2, 6: 1, 9: 1, 15: 1};
        final line = Paint()
          ..color = const Color(0xFF2B5E91)
          ..strokeWidth = 3;
        canvas.drawLine(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          line,
        );
        canvas.drawLine(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          line,
        );
        final reveal = (p * 4).floor();
        for (var i = 0; i < 16; i++) {
          if (grid[i] != 0) {
            text('${grid[i]}', ctr(i), const Color(0xFF13213C), cell * .45);
          } else {
            final k = answer.keys.toList().indexOf(i);
            if (k < reveal) {
              text('${answer[i]}', ctr(i), const Color(0xFF1D6BB0), cell * .45);
            }
          }
        }
    }
  }

  @override
  bool shouldRepaint(_DemoPainter old) => true;
}
