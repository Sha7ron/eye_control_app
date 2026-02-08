import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  final List<Offset> _gazeHistory = [];
  final int _historySize = 10;

  final List<CalibrationPoint> _calibrationPoints = [];
  bool _isCalibrated = false;

  Size? _screenSize;

  void setScreenSize(Size size) {
    _screenSize = size;
  }

  List<CalibrationPoint> createCalibrationPoints(Size screenSize) {
    final marginX = screenSize.width * 0.15;
    final marginY = screenSize.height * 0.15;

    final points = [
      CalibrationPoint(x: screenSize.width / 2, y: screenSize.height / 2, index: 0),
      CalibrationPoint(x: marginX, y: marginY, index: 1),
      CalibrationPoint(x: screenSize.width - marginX, y: marginY, index: 2),
      CalibrationPoint(x: marginX, y: screenSize.height - marginY, index: 3),
      CalibrationPoint(x: screenSize.width - marginX, y: screenSize.height - marginY, index: 4),
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

  void addCalibrationData(int pointIndex, Face face, Size imageSize, Size screenSize) {
    if (pointIndex >= _calibrationPoints.length) return;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye != null && rightEye != null) {
      final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
      final eyeCenterY = (leftEye.position.y + rightEye.position.y) / 2;

      _calibrationPoints[pointIndex].calibrate(eyeCenterX, eyeCenterY);
      _isCalibrated = _calibrationPoints.every((p) => p.isCalibrated);

      print('✓ Point $pointIndex: eye center ($eyeCenterX, $eyeCenterY) → screen (${_calibrationPoints[pointIndex].x}, ${_calibrationPoints[pointIndex].y})');
    }
  }

  bool get isCalibrated => _isCalibrated;
  List<CalibrationPoint> get calibrationPoints => _calibrationPoints;

  GazeData? calculateGaze(Face face, Size imageSize, Size screenSize) {
    if (_screenSize == null) {
      _screenSize = screenSize;
    }

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) {
      return null;
    }

    final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
    final eyeCenterY = (leftEye.position.y + rightEye.position.y) / 2;

    Offset gazePoint;

    if (_isCalibrated) {
      gazePoint = _interpolateGaze(eyeCenterX, eyeCenterY, screenSize);
    } else {
      final scaleX = screenSize.width / imageSize.height;
      final scaleY = screenSize.height / imageSize.width;
      final mappedX = screenSize.width - (eyeCenterX * scaleX);
      final mappedY = eyeCenterY * scaleY;
      gazePoint = Offset(mappedX, mappedY);
    }

    final smoothedGaze = _applySmoothing(gazePoint);
    final confidence = _isCalibrated ? 0.95 : 0.7;

    return GazeData(
      gazePoint: smoothedGaze,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  Offset _interpolateGaze(double eyeX, double eyeY, Size screenSize) {
    final distances = _calibrationPoints.map((point) {
      final dx = point.eyeCenterX! - eyeX;
      final dy = point.eyeCenterY! - eyeY;
      final dist = math.sqrt(dx * dx + dy * dy);
      return {'point': point, 'distance': dist};
    }).toList()
      ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;

    for (int i = 0; i < math.min(4, distances.length); i++) {
      final data = distances[i];
      final point = data['point'] as CalibrationPoint;
      final distance = data['distance'] as double;

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
    if (_gazeHistory.length < 3) return point;

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

  void reset() {
    _gazeHistory.clear();
    _calibrationPoints.clear();
    _isCalibrated = false;
  }
}