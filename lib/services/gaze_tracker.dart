import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class GazeData {
  final Offset gazePoint;
  final double confidence;
  final DateTime timestamp;

  GazeData({
    required this.gazePoint,
    required this.confidence,
    required this.timestamp,
  });
}

class GazeTracker {
  // Smoothing buffer for gaze points
  final List<Offset> _gazeHistory = [];
  final int _historySize = 5;

  // Screen dimensions
  Size? _screenSize;

  void setScreenSize(Size size) {
    _screenSize = size;
  }

  GazeData? calculateGaze(Face face, Size imageSize, Size screenSize) {
    if (_screenSize == null) {
      _screenSize = screenSize;
    }

    // Get eye landmarks
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) {
      return null;
    }

    // Calculate center point between eyes
    final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
    final eyeCenterY = (leftEye.position.y + rightEye.position.y) / 2;

    // Convert to screen coordinates (using same transformation as painter)
    final gazeX = _translateX(eyeCenterX, screenSize, imageSize);
    final gazeY = _translateY(eyeCenterY, screenSize, imageSize);

    final rawGazePoint = Offset(gazeX, gazeY);

    // Apply smoothing
    final smoothedGaze = _applySmoothig(rawGazePoint);

    // Calculate confidence based on face tracking confidence
    final confidence = face.trackingId != null ? 0.8 : 0.6;

    return GazeData(
      gazePoint: smoothedGaze,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  double _translateX(double x, Size screenSize, Size imageSize) {
    // For rotation270deg with front camera
    return screenSize.width - (x * screenSize.width / imageSize.height);
  }

  double _translateY(double y, Size screenSize, Size imageSize) {
    // For rotation270deg
    return y * screenSize.height / imageSize.width;
  }

  Offset _applySmoothig(Offset point) {
    _gazeHistory.add(point);

    // Keep only recent history
    if (_gazeHistory.length > _historySize) {
      _gazeHistory.removeAt(0);
    }

    // Calculate average
    double avgX = 0;
    double avgY = 0;

    for (final p in _gazeHistory) {
      avgX += p.dx;
      avgY += p.dy;
    }

    return Offset(
      avgX / _gazeHistory.length,
      avgY / _gazeHistory.length,
    );
  }

  void reset() {
    _gazeHistory.clear();
  }
}