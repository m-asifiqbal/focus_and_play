// Tiny static board for each game (island picker, how-to-play, ad break card).

import 'package:flutter/material.dart';

import '../../../domain/game_id.dart';

class GamePreview extends StatelessWidget {
  const GamePreview({super.key, required this.game, this.size = 72});
  final GameId game;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _PreviewPainter(game)),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.game);
  final GameId game;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 72;
    canvas.scale(s);
    final bg = switch (game) {
      GameId.thread => 0xFFFFE5D9,
      GameId.quilt => 0xFFDDF5E6,
      GameId.twist => 0xFFECE6FD,
      GameId.sudoku => 0xFFDCEEFC,
      GameId.sleuth => 0xFFFDE4EE,
      GameId.bridges => 0xFFD9F5F1,
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 72, 72),
        const Radius.circular(16),
      ),
      Paint()..color = Color(bg),
    );
    final navy = Paint()..color = const Color(0xFF13213C);
    switch (game) {
      case GameId.thread:
        canvas.drawPath(
          Path()
            ..moveTo(14, 14)
            ..lineTo(58, 14)
            ..lineTo(58, 30)
            ..lineTo(14, 30)
            ..lineTo(14, 46)
            ..lineTo(58, 46)
            ..lineTo(58, 58),
          Paint()
            ..color = const Color(0xFFF0582A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawCircle(const Offset(14, 14), 7, navy);
        canvas.drawCircle(const Offset(58, 58), 7, navy);
      case GameId.quilt:
        void r(double x, double y, double w, double h, int c) =>
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, w, h),
                const Radius.circular(5),
              ),
              Paint()..color = Color(c),
            );
        r(8, 8, 34, 22, 0xFF9ED9B0);
        r(46, 8, 18, 40, 0xFFFFD68A);
        r(8, 34, 34, 30, 0xFFA9D3F5);
        r(46, 52, 18, 12, 0xFFF7B6C2);
        canvas.drawCircle(
          const Offset(25, 19),
          6,
          Paint()..color = Colors.white,
        );
      case GameId.twist:
        for (var i = 0; i < 9; i++) {
          final x = 8.0 + (i % 3) * 20, y = 8.0 + (i ~/ 3) * 20;
          final c = i < 3 ? 0xFF8A4FD8 : (i == 4 ? 0xFFFFC233 : 0xFFFFFFFF);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 17, 17),
              const Radius.circular(5),
            ),
            Paint()..color = Color(c),
          );
        }
      case GameId.sudoku:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 8, 56, 56),
            const Radius.circular(8),
          ),
          Paint()..color = Colors.white,
        );
        final line = Paint()
          ..color = const Color(0xFF2B5E91)
          ..strokeWidth = 2;
        canvas.drawLine(const Offset(36, 8), const Offset(36, 64), line);
        canvas.drawLine(const Offset(8, 26.7), const Offset(64, 26.7), line);
        canvas.drawLine(const Offset(8, 45.3), const Offset(64, 45.3), line);
        canvas.drawCircle(const Offset(22, 17), 4, navy);
        canvas.drawCircle(const Offset(50, 36), 4, navy);
        canvas.drawCircle(
          const Offset(22, 55),
          4,
          Paint()..color = const Color(0xFF1E9BDC),
        );
      case GameId.sleuth:
        // Three guesses of a word: grey, yellow and green tiles, the last one solved.
        const rows = [
          [0xFFD9DEE5, 0xFFFFC233, 0xFFD9DEE5, 0xFFD9DEE5],
          [0xFF2FB36B, 0xFFD9DEE5, 0xFFFFC233, 0xFFD9DEE5],
          [0xFF2FB36B, 0xFF2FB36B, 0xFF2FB36B, 0xFF2FB36B],
        ];
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 4; c++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(8.0 + c * 14.5, 11.0 + r * 18, 12.5, 14.5),
                const Radius.circular(4),
              ),
              Paint()..color = Color(rows[r][c]),
            );
          }
        }
      case GameId.bridges:
        // Four islets joined by bridges (one double).
        final bridge = Paint()
          ..color = const Color(0xFF8A5A2B)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(18, 17), const Offset(54, 17), bridge);
        canvas.drawLine(const Offset(18, 21), const Offset(54, 21), bridge);
        canvas.drawLine(const Offset(54, 19), const Offset(54, 54), bridge);
        canvas.drawLine(const Offset(18, 19), const Offset(18, 54), bridge);
        canvas.drawLine(const Offset(18, 54), const Offset(54, 54), bridge);
        for (final p in const [
          Offset(18, 19),
          Offset(54, 19),
          Offset(18, 54),
          Offset(54, 54),
        ]) {
          canvas.drawCircle(p, 8, Paint()..color = const Color(0xFF14B8A6));
          canvas.drawCircle(
            p,
            8,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.game != game;
}
