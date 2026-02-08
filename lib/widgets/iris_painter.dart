import 'package:flutter/material.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

class IrisPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size canvasSize;

  IrisPainter({
    required this.faces,
    required this.imageSize,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factors
    final double scaleX = canvasSize.width / imageSize.width;
    final double scaleY = canvasSize.height / imageSize.height;

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

    final Paint debugPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    for (final face in faces) {
      // Draw face bounding box
      final bbox = face.boundingBox;
      canvas.drawRect(
        Rect.fromLTRB(
          bbox.topLeft.x * scaleX,
          bbox.topLeft.y * scaleY,
          bbox.bottomRight.x * scaleX,
          bbox.bottomRight.y * scaleY,
        ),
        facePaint,
      );

      // Draw iris tracking
      if (face.eyes != null) {
        // Debug: Print raw iris coordinates
        if (face.eyes!.leftEye != null) {
          print('Left iris raw: (${face.eyes!.leftEye!.irisCenter.x}, ${face.eyes!.leftEye!.irisCenter.y})');
          print('Left iris scaled: (${face.eyes!.leftEye!.irisCenter.x * scaleX}, ${face.eyes!.leftEye!.irisCenter.y * scaleY})');
        }

        _drawEye(canvas, face.eyes!.leftEye, irisPaint, irisOutlinePaint, scaleX, scaleY);
        _drawEye(canvas, face.eyes!.rightEye, irisPaint, irisOutlinePaint, scaleX, scaleY);

        // Debug: Also draw face landmarks for comparison
        if (face.landmarks.leftEye != null) {
          canvas.drawCircle(
            Offset(
              face.landmarks.leftEye!.x * scaleX,
              face.landmarks.leftEye!.y * scaleY,
            ),
            4,
            debugPaint,
          );
        }
        if (face.landmarks.rightEye != null) {
          canvas.drawCircle(
            Offset(
              face.landmarks.rightEye!.x * scaleX,
              face.landmarks.rightEye!.y * scaleY,
            ),
            4,
            debugPaint,
          );
        }
      }
    }
  }

  void _drawEye(Canvas canvas, Eye? eye, Paint irisPaint, Paint outlinePaint, double scaleX, double scaleY) {
    if (eye == null) return;

    // Draw iris center
    canvas.drawCircle(
      Offset(eye.irisCenter.x * scaleX, eye.irisCenter.y * scaleY),
      6,
      irisPaint,
    );

    // Draw iris contour
    if (eye.irisContour.length >= 4) {
      final path = Path();
      path.moveTo(eye.irisContour[0].x * scaleX, eye.irisContour[0].y * scaleY);
      for (int i = 1; i < eye.irisContour.length; i++) {
        path.lineTo(eye.irisContour[i].x * scaleX, eye.irisContour[i].y * scaleY);
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