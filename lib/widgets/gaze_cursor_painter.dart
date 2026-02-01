import 'package:flutter/material.dart';

class GazeCursorPainter extends CustomPainter {
  final Offset? gazePoint;
  final double confidence;

  GazeCursorPainter({
    required this.gazePoint,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gazePoint == null) return;

    // Draw outer circle (confidence indicator)
    final outerPaint = Paint()
      ..color = Colors.purple.withOpacity(0.3 * confidence)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(gazePoint!, 30, outerPaint);

    // Draw middle circle
    final middlePaint = Paint()
      ..color = Colors.purple.withOpacity(0.5 * confidence)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(gazePoint!, 20, middlePaint);

    // Draw inner circle (gaze point)
    final innerPaint = Paint()
      ..color = Colors.purple.withOpacity(0.9 * confidence)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(gazePoint!, 10, innerPaint);

    // Draw center dot
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(gazePoint!, 3, centerPaint);
  }

  @override
  bool shouldRepaint(GazeCursorPainter oldDelegate) {
    return oldDelegate.gazePoint != gazePoint ||
        oldDelegate.confidence != confidence;
  }
}