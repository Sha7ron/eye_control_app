import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
      ..color = Colors.red;

    final Paint eyePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    for (final Face face in faces) {
      // Draw bounding box
      canvas.drawRect(
        Rect.fromLTRB(
          translateX(face.boundingBox.left, size),
          translateY(face.boundingBox.top, size),
          translateX(face.boundingBox.right, size),
          translateY(face.boundingBox.bottom, size),
        ),
        paint,
      );

      // Draw landmarks
      void paintLandmark(FaceLandmarkType type, Paint landmarkPaint) {
        final landmark = face.landmarks[type];
        if (landmark != null) {
          canvas.drawCircle(
            Offset(
              translateX(landmark.position.x.toDouble(), size),
              translateY(landmark.position.y.toDouble(), size),
            ),
            type == FaceLandmarkType.leftEye || type == FaceLandmarkType.rightEye ? 8 : 5,
            landmarkPaint,
          );
        }
      }

      // Draw eyes (blue)
      paintLandmark(FaceLandmarkType.leftEye, eyePaint);
      paintLandmark(FaceLandmarkType.rightEye, eyePaint);

      // Draw other landmarks (red)
      paintLandmark(FaceLandmarkType.noseBase, landmarkPaint);
      paintLandmark(FaceLandmarkType.leftMouth, landmarkPaint);
      paintLandmark(FaceLandmarkType.rightMouth, landmarkPaint);
    }
  }

  double translateX(double x, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * size.width / imageSize.height;
      case InputImageRotation.rotation270deg:
        return size.width - x * size.width / imageSize.height;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        if (cameraLensDirection == CameraLensDirection.front) {
          return size.width - x * size.width / imageSize.width;
        } else {
          return x * size.width / imageSize.width;
        }
    }
  }

  double translateY(double y, Size size) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * size.height / imageSize.width;
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * size.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}