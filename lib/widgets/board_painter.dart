import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../models/game_theme.dart';

class BoardPainter extends CustomPainter {
  final FanoronaVariant variant;
  final GameThemeData theme;
  final List<BoardPoint> highlightedPoints;

  BoardPainter({
    required this.variant,
    required this.theme,
    this.highlightedPoints = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int cols = variant.cols;
    final int rows = variant.rows;

    final double cellW = size.width / (cols - 1);
    final double cellH = size.height / (rows - 1);

    final linePaint = Paint()
      ..color = theme.gridLineColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = theme.activeHighlightColor.withAlpha(140)
      ..style = PaintingStyle.fill;

    // Yatay çizgiler
    for (int y = 0; y < rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        linePaint,
      );
    }

    // Dikey çizgiler
    for (int x = 0; x < cols; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        linePaint,
      );
    }

    // Çapraz çizgiler
    for (int y = 0; y < rows - 1; y++) {
      for (int x = 0; x < cols - 1; x++) {
        final current = BoardPoint(x, y);
        if (current.isStrongIntersection) {
          canvas.drawLine(
            Offset(x * cellW, y * cellH),
            Offset((x + 1) * cellW, (y + 1) * cellH),
            linePaint,
          );
        } else {
          canvas.drawLine(
            Offset((x + 1) * cellW, y * cellH),
            Offset(x * cellW, (y + 1) * cellH),
            linePaint,
          );
        }
      }
    }

    // Gidilebilecek hedef halkaları
    for (final pt in highlightedPoints) {
      final center = Offset(pt.x * cellW, pt.y * cellH);
      canvas.drawCircle(center, 9, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.highlightedPoints != highlightedPoints ||
        oldDelegate.theme.id != theme.id ||
        oldDelegate.variant != variant;
  }
}