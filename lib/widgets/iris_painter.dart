import 'package:flutter/material.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

class IrisPainter extends CustomPainter {
  final List<Face> faces;

  IrisPainter({required this.faces});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint facePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.greenAccent;

    final Paint irisPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.8);

    final Paint irisOutlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.cyan;

    for (final face in faces) {
      // Draw face bounding box
      final bbox = face.boundingBox;
      canvas.drawRect(
        Rect.fromLTRB(
          bbox.topLeft.x,
          bbox.topLeft.y,
          bbox.bottomRight.x,
          bbox.bottomRight.y,
        ),
        facePaint,
      );

      // Draw iris tracking
      if (face.eyes != null) {
        _drawEye(canvas, face.eyes!.leftEye, irisPaint, irisOutlinePaint);
        _drawEye(canvas, face.eyes!.rightEye, irisPaint, irisOutlinePaint);
      }
    }
  }

  void _drawEye(Canvas canvas, Eye? eye, Paint irisPaint, Paint outlinePaint) {
    if (eye == null) return;

    // Draw iris center
    canvas.drawCircle(
      Offset(eye.irisCenter.x, eye.irisCenter.y),
      6,
      irisPaint,
    );

    // Draw iris contour
    if (eye.irisContour.length >= 4) {
      final path = Path();
      path.moveTo(eye.irisContour[0].x, eye.irisContour[0].y);
      for (int i = 1; i < eye.irisContour.length; i++) {
        path.lineTo(eye.irisContour[i].x, eye.irisContour[i].y);
      }
      path.close();
      canvas.drawPath(path, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(IrisPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}