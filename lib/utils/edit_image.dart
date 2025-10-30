import 'package:flutter/material.dart';

// Dữ liệu 1 nét vẽ
class DrawnLine {
  List<Offset> points;
  Color color;
  double strokeWidth;

  DrawnLine(this.points, this.color, this.strokeWidth);
}

/// Dữ liệu chữ ghi lên ảnh
class TextOverlay {
  final String text;
  final Offset position;
  final Color color;

  TextOverlay({
    required this.text,
    required this.position,
    required this.color,
  });
}

/// CustomPainter để hiển thị nét vẽ & chữ
class DrawingPainter extends CustomPainter {
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;
  final List<TextOverlay> texts;

  DrawingPainter(this.lines, this.currentLine, this.texts);

  @override
  void paint(Canvas canvas, Size size) {
    // Nét vẽ
    for (final line in [...lines, if (currentLine != null) currentLine!]) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }

    // Text
    for (final t in texts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, t.position);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
