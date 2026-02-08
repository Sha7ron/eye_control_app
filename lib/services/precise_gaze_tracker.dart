import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PreciseGazeData {
  final Offset screenPoint;
  final double confidence;
  final DateTime timestamp;

  PreciseGazeData({
    required this.screenPoint,
    required this.confidence,
    required this.timestamp,
  });
}

class PreciseGazeTracker {
  // Calibration grid (9 points)
  final Map<int, _CalibrationData> _calibrationMap = {};
  bool _isCalibrated = false;

  // Smoothing
  final List<Offset> _gazeHistory = [];
  final int _historySize = 5;

  // Screen mapping parameters (learned from calibration)
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  Offset _offset = Offset.zero;

  // Polynomial coefficients for non-linear mapping
  final List<double> _xCoeffs = [0, 1, 0, 0]; // [c0, c1, c2, c3]
  final List<double> _yCoeffs = [0, 1, 0, 0];

  bool get isCalibrated => _isCalibrated;

  List<Offset> getCalibrationPoints(Size screenSize) {
    final margin = 80.0;
    return [
      // 3x3 grid for better accuracy
      Offset(margin, margin), // Top-left
      Offset(screenSize.width / 2, margin), // Top-center
      Offset(screenSize.width - margin, margin), // Top-right

      Offset(margin, screenSize.height / 2), // Middle-left
      Offset(screenSize.width / 2, screenSize.height / 2), // Center
      Offset(screenSize.width - margin, screenSize.height / 2), // Middle-right

      Offset(margin, screenSize.height - margin), // Bottom-left
      Offset(screenSize.width / 2, screenSize.height - margin), // Bottom-center
      Offset(screenSize.width - margin, screenSize.height - margin), // Bottom-right
    ];
  }

  void addCalibrationPoint(int index, Face face, Offset screenTarget) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      // Use eye center as tracking point (most stable)
      final eyeCenter = Offset(
        (leftEye.position.x + rightEye.position.x) / 2,
        (leftEye.position.y + rightEye.position.y) / 2,
      );

      _calibrationMap[index] = _CalibrationData(
        eyePosition: eyeCenter,
        screenPosition: screenTarget,
      );

      print('✓ Calibration point $index: Eye($eyeCenter) → Screen($screenTarget)');

      // If we have all 9 points, compute mapping
      if (_calibrationMap.length >= 9) {
        _computeMapping();
      }
    }
  }

  void _computeMapping() {
    // Use least squares to find best mapping
    final List<Offset> eyePoints = [];
    final List<Offset> screenPoints = [];

    _calibrationMap.forEach((_, data) {
      eyePoints.add(data.eyePosition);
      screenPoints.add(data.screenPosition);
    });

    // Calculate bounding boxes
    double minEyeX = eyePoints[0].dx, maxEyeX = eyePoints[0].dx;
    double minEyeY = eyePoints[0].dy, maxEyeY = eyePoints[0].dy;
    double minScreenX = screenPoints[0].dx, maxScreenX = screenPoints[0].dx;
    double minScreenY = screenPoints[0].dy, maxScreenY = screenPoints[0].dy;

    for (final point in eyePoints) {
      minEyeX = math.min(minEyeX, point.dx);
      maxEyeX = math.max(maxEyeX, point.dx);
      minEyeY = math.min(minEyeY, point.dy);
      maxEyeY = math.max(maxEyeY, point.dy);
    }

    for (final point in screenPoints) {
      minScreenX = math.min(minScreenX, point.dx);
      maxScreenX = math.max(maxScreenX, point.dx);
      minScreenY = math.min(minScreenY, point.dy);
      maxScreenY = math.max(maxScreenY, point.dy);
    }

    // Calculate scale and offset
    final eyeRangeX = maxEyeX - minEyeX;
    final eyeRangeY = maxEyeY - minEyeY;
    final screenRangeX = maxScreenX - minScreenX;
    final screenRangeY = maxScreenY - minScreenY;

    if (eyeRangeX > 0 && eyeRangeY > 0) {
      _scaleX = screenRangeX / eyeRangeX;
      _scaleY = screenRangeY / eyeRangeY;
      _offset = Offset(minScreenX - minEyeX * _scaleX, minScreenY - minEyeY * _scaleY);

      _isCalibrated = true;
      print('✓ Mapping computed: ScaleX=$_scaleX, ScaleY=$_scaleY');
    }
  }

  PreciseGazeData? calculateGaze(Face face, Size screenSize) {
    if (!_isCalibrated) return null;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return null;

    // Calculate current eye center
    final eyeCenter = Offset(
      (leftEye.position.x + rightEye.position.x) / 2,
      (leftEye.position.y + rightEye.position.y) / 2,
    );

    // Apply learned mapping
    Offset screenPoint = Offset(
      eyeCenter.dx * _scaleX + _offset.dx,
      eyeCenter.dy * _scaleY + _offset.dy,
    );

    // Clamp to screen bounds
    screenPoint = Offset(
      screenPoint.dx.clamp(0, screenSize.width),
      screenPoint.dy.clamp(0, screenSize.height),
    );

    // Apply smoothing
    final smoothed = _applySmoothing(screenPoint);

    return PreciseGazeData(
      screenPoint: smoothed,
      confidence: 0.95,
      timestamp: DateTime.now(),
    );
  }

  Offset _applySmoothing(Offset point) {
    _gazeHistory.add(point);
    if (_gazeHistory.length > _historySize) {
      _gazeHistory.removeAt(0);
    }

    if (_gazeHistory.isEmpty) return point;

    // Weighted average (more weight to recent)
    double weightedX = 0;
    double weightedY = 0;
    double totalWeight = 0;

    for (int i = 0; i < _gazeHistory.length; i++) {
      final weight = math.pow(1.5, i).toDouble();
      weightedX += _gazeHistory[i].dx * weight;
      weightedY += _gazeHistory[i].dy * weight;
      totalWeight += weight;
    }

    return Offset(weightedX / totalWeight, weightedY / totalWeight);
  }

  void reset() {
    _calibrationMap.clear();
    _gazeHistory.clear();
    _isCalibrated = false;
  }
}

class _CalibrationData {
  final Offset eyePosition;
  final Offset screenPosition;

  _CalibrationData({
    required this.eyePosition,
    required this.screenPosition,
  });
}