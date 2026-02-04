import 'dart:ui';
import 'dart:math' as math;
import 'package:face_detection_tflite/face_detection_tflite.dart';
import '../models/calibration_point.dart';

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
  // Smoothing buffer
  final List<Offset> _gazeHistory = [];
  final int _historySize = 10;

  // Calibration data
  final List<CalibrationPoint> _calibrationPoints = [];
  bool _isCalibrated = false;

  Size? _screenSize;

  void setScreenSize(Size size) {
    _screenSize = size;
  }

  // Create 9-point calibration
  List<CalibrationPoint> createCalibrationPoints(Size screenSize) {
    final marginX = screenSize.width * 0.15;
    final marginY = screenSize.height * 0.15;

    final points = [
      // Center first (most important)
      CalibrationPoint(x: screenSize.width / 2, y: screenSize.height / 2, index: 0),

      // Four corners
      CalibrationPoint(x: marginX, y: marginY, index: 1),
      CalibrationPoint(x: screenSize.width - marginX, y: marginY, index: 2),
      CalibrationPoint(x: marginX, y: screenSize.height - marginY, index: 3),
      CalibrationPoint(x: screenSize.width - marginX, y: screenSize.height - marginY, index: 4),

      // Mid points
      CalibrationPoint(x: screenSize.width / 2, y: marginY, index: 5),
      CalibrationPoint(x: screenSize.width / 2, y: screenSize.height - marginY, index: 6),
      CalibrationPoint(x: marginX, y: screenSize.height / 2, index: 7),
      CalibrationPoint(x: screenSize.width - marginX, y: screenSize.height / 2, index: 8),
    ];

    _calibrationPoints.clear();
    _calibrationPoints.addAll(points);
    _isCalibrated = false;

    return points;
  }

  void addCalibrationData(int pointIndex, Face face, Size screenSize) {
    if (pointIndex >= _calibrationPoints.length) return;

    // Get iris centers from both eyes
    final leftIris = face.eyes?.leftEye?.irisCenter;
    final rightIris = face.eyes?.rightEye?.irisCenter;

    if (leftIris != null && rightIris != null) {
      // Average the iris positions for gaze point
      final gazeX = (leftIris.x + rightIris.x) / 2;
      final gazeY = (leftIris.y + rightIris.y) / 2;

      _calibrationPoints[pointIndex].calibrate(gazeX, gazeY);

      _isCalibrated = _calibrationPoints.every((p) => p.isCalibrated);

      print('✓ Calibration point $pointIndex: iris at ($gazeX, $gazeY) → screen (${_calibrationPoints[pointIndex].x}, ${_calibrationPoints[pointIndex].y})');
      print('Progress: ${_calibrationPoints.where((p) => p.isCalibrated).length}/${_calibrationPoints.length}');
    }
  }

  bool get isCalibrated => _isCalibrated;
  List<CalibrationPoint> get calibrationPoints => _calibrationPoints;

  GazeData? calculateGaze(Face face, Size screenSize) {
    if (_screenSize == null) {
      _screenSize = screenSize;
    }

    // Get iris centers
    final leftIris = face.eyes?.leftEye?.irisCenter;
    final rightIris = face.eyes?.rightEye?.irisCenter;

    if (leftIris == null || rightIris == null) {
      return null;
    }

    // Calculate average iris position
    final irisX = (leftIris.x + rightIris.x) / 2;
    final irisY = (leftIris.y + rightIris.y) / 2;

    Offset gazePoint;

    if (_isCalibrated) {
      // Use calibration for accurate mapping
      gazePoint = _interpolateGaze(irisX, irisY, screenSize);
    } else {
      // Fallback to simple proportional mapping
      // Iris coordinates are already in screen space from the package
      gazePoint = Offset(irisX, irisY);
    }

    // Apply smoothing
    final smoothedGaze = _applySmoothing(gazePoint);

    // Calculate confidence
    final confidence = _isCalibrated ? 0.95 : 0.7;

    return GazeData(
      gazePoint: smoothedGaze,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  Offset _interpolateGaze(double irisX, double irisY, Size screenSize) {
    // Find nearest calibration points and interpolate
    final distances = _calibrationPoints.map((point) {
      final dx = point.eyeCenterX! - irisX;
      final dy = point.eyeCenterY! - irisY;
      final dist = math.sqrt(dx * dx + dy * dy);
      return {'point': point, 'distance': dist};
    }).toList()
      ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    // Use 4 nearest points for interpolation
    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;

    for (int i = 0; i < math.min(4, distances.length); i++) {
      final data = distances[i];
      final point = data['point'] as CalibrationPoint;
      final distance = data['distance'] as double;

      // Inverse distance weighting
      final weight = distance > 0 ? 1 / math.pow(distance, 2) : 1000;

      totalWeight += weight;
      weightedX += point.x * weight;
      weightedY += point.y * weight;
    }

    if (totalWeight > 0) {
      return Offset(
        (weightedX / totalWeight).clamp(0, screenSize.width),
        (weightedY / totalWeight).clamp(0, screenSize.height),
      );
    }

    return Offset(screenSize.width / 2, screenSize.height / 2);
  }

  Offset _applySmoothing(Offset point) {
    _gazeHistory.add(point);

    if (_gazeHistory.length > _historySize) {
      _gazeHistory.removeAt(0);
    }

    if (_gazeHistory.length < 3) {
      return point;
    }

    // Weighted moving average
    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;

    for (int i = 0; i < _gazeHistory.length; i++) {
      final weight = math.pow(1.3, i).toDouble();
      final p = _gazeHistory[i];

      totalWeight += weight;
      weightedX += p.dx * weight;
      weightedY += p.dy * weight;
    }

    return Offset(weightedX / totalWeight, weightedY / totalWeight);
  }

  Offset? getRawIrisCenter(Face face) {
    final leftIris = face.eyes?.leftEye?.irisCenter;
    final rightIris = face.eyes?.rightEye?.irisCenter;

    if (leftIris == null || rightIris == null) {
      return null;
    }

    return Offset(
      (leftIris.x + rightIris.x) / 2,
      (leftIris.y + rightIris.y) / 2,
    );
  }

  void reset() {
    _gazeHistory.clear();
    _calibrationPoints.clear();
    _isCalibrated = false;
  }
}