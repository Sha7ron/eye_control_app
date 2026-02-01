import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;

  FaceDetectorPainter({
    required this.faces,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    final Paint eyePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    for (final Face face in faces) {
      // Draw bounding box
      final Rect boundingBox = _scaleRect(
        rect: face.boundingBox,
      );
      canvas.drawRect(boundingBox, paint);

      // Draw face landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      final nose = face.landmarks[FaceLandmarkType.noseBase];
      final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
      final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];

      // Draw eyes with larger circles
      if (leftEye != null) {
        final point = _scalePoint(
          x: leftEye.position.x.toDouble(),
          y: leftEye.position.y.toDouble(),
        );
        canvas.drawCircle(point, 8, eyePaint);
      }

      if (rightEye != null) {
        final point = _scalePoint(
          x: rightEye.position.x.toDouble(),
          y: rightEye.position.y.toDouble(),
        );
        canvas.drawCircle(point, 8, eyePaint);
      }

      // Draw other landmarks
      if (nose != null) {
        final point = _scalePoint(
          x: nose.position.x.toDouble(),
          y: nose.position.y.toDouble(),
        );
        canvas.drawCircle(point, 5, landmarkPaint);
      }

      if (leftMouth != null) {
        final point = _scalePoint(
          x: leftMouth.position.x.toDouble(),
          y: leftMouth.position.y.toDouble(),
        );
        canvas.drawCircle(point, 5, landmarkPaint);
      }

      if (rightMouth != null) {
        final point = _scalePoint(
          x: rightMouth.position.x.toDouble(),
          y: rightMouth.position.y.toDouble(),
        );
        canvas.drawCircle(point, 5, landmarkPaint);
      }
    }
  }

  Offset _scalePoint({
    required double x,
    required double y,
  }) {
    // Simple mirrored scaling - common for front camera
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    return Offset(
      widgetSize.width - (x * scaleX),  // Mirror horizontally
      y * scaleY,
    );
  }

  Rect _scaleRect({
    required Rect rect,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    return Rect.fromLTRB(
      widgetSize.width - (rect.right * scaleX),  // Mirror horizontally
      rect.top * scaleY,
      widgetSize.width - (rect.left * scaleX),   // Mirror horizontally
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}