import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  FaceDetectorPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.greenAccent;

    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    for (final Face face in faces) {
      final left = translateX(face.boundingBox.left, size);
      final top = translateY(face.boundingBox.top, size);
      final right = translateX(face.boundingBox.right, size);
      final bottom = translateY(face.boundingBox.bottom, size);

      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      void paintLandmark(FaceLandmarkType type) {
        final landmark = face.landmarks[type];
        if (landmark != null) {
          canvas.drawCircle(
            Offset(
              translateX(landmark.position.x.toDouble(), size),
              translateY(landmark.position.y.toDouble(), size),
            ),
            5,
            landmarkPaint,
          );
        }
      }

      paintLandmark(FaceLandmarkType.leftEye);
      paintLandmark(FaceLandmarkType.rightEye);
    }
  }

  double translateX(double x, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation270deg:
        return size.width - x * size.width / imageSize.height;
      default:
        return x * size.width / imageSize.width;
    }
  }

  double translateY(double y, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation270deg:
        return y * size.height / imageSize.width;
      default:
        return y * size.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}