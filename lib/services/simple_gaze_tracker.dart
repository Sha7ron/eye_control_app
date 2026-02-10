import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class GazePoint {
  final Offset position;
  final double confidence;

  GazePoint({required this.position, required this.confidence});
}

class SimpleGazeTracker {
  // Calibration storage
  final Map<int, _CalibrationData> _calibrationMap = {};
  bool _isCalibrated = false;

  // Smoothing
  final List<Offset> _history = [];
  final int _historySize = 5;

  // Mapping
  double _minEyeX = 0, _maxEyeX = 0;
  double _minEyeY = 0, _maxEyeY = 0;
  double _minScreenX = 0, _maxScreenX = 0;
  double _minScreenY = 0, _maxScreenY = 0;

  bool get isCalibrated => _isCalibrated;

  List<Offset> getCalibrationPoints(Size screenSize) {
    final margin = 80.0;
    return [
      // Simple 9-point grid
      Offset(margin, margin),
      Offset(screenSize.width / 2, margin),
      Offset(screenSize.width - margin, margin),

      Offset(margin, screenSize.height / 2),
      Offset(screenSize.width / 2, screenSize.height / 2),
      Offset(screenSize.width - margin, screenSize.height / 2),

      Offset(margin, screenSize.height - margin),
      Offset(screenSize.width / 2, screenSize.height - margin),
      Offset(screenSize.width - margin, screenSize.height - margin),
    ];
  }

  void addCalibrationSample(int index, Face face, Offset screenPoint) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return;

    final eyeCenter = Offset(
      (leftEye.position.x + rightEye.position.x) / 2,
      (leftEye.position.y + rightEye.position.y) / 2,
    );

    _calibrationMap[index] = _CalibrationData(
      eyePosition: eyeCenter,
      screenPosition: screenPoint,
    );

    print('Calibration $index: Eye(${eyeCenter.dx.toInt()}, ${eyeCenter.dy.toInt()}) → Screen(${screenPoint.dx.toInt()}, ${screenPoint.dy.toInt()})');

    if (_calibrationMap.length >= 9) {
      _computeMapping();
    }
  }

  void _computeMapping() {
    if (_calibrationMap.length < 9) return;

    // Find bounds
    _minEyeX = double.infinity;
    _maxEyeX = double.negativeInfinity;
    _minEyeY = double.infinity;
    _maxEyeY = double.negativeInfinity;
    _minScreenX = double.infinity;
    _maxScreenX = double.negativeInfinity;
    _minScreenY = double.infinity;
    _maxScreenY = double.negativeInfinity;

    _calibrationMap.forEach((_, data) {
      _minEyeX = math.min(_minEyeX, data.eyePosition.dx);
      _maxEyeX = math.max(_maxEyeX, data.eyePosition.dx);
      _minEyeY = math.min(_minEyeY, data.eyePosition.dy);
      _maxEyeY = math.max(_maxEyeY, data.eyePosition.dy);

      _minScreenX = math.min(_minScreenX, data.screenPosition.dx);
      _maxScreenX = math.max(_maxScreenX, data.screenPosition.dx);
      _minScreenY = math.min(_minScreenY, data.screenPosition.dy);
      _maxScreenY = math.max(_maxScreenY, data.screenPosition.dy);
    });

    _isCalibrated = true;
    print('✓ Calibration complete!');
  }

  GazePoint? calculateGaze(Face face, Size screenSize) {
    if (!_isCalibrated) return null;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return null;

    final eyeCenter = Offset(
      (leftEye.position.x + rightEye.position.x) / 2,
      (leftEye.position.y + rightEye.position.y) / 2,
    );

    // Map eye position to screen
    final eyeRangeX = _maxEyeX - _minEyeX;
    final eyeRangeY = _maxEyeY - _minEyeY;
    final screenRangeX = _maxScreenX - _minScreenX;
    final screenRangeY = _maxScreenY - _minScreenY;

    if (eyeRangeX == 0 || eyeRangeY == 0) return null;

    final normalizedX = (eyeCenter.dx - _minEyeX) / eyeRangeX;
    final normalizedY = (eyeCenter.dy - _minEyeY) / eyeRangeY;

    Offset screenPoint = Offset(
      _minScreenX + normalizedX * screenRangeX,
      _minScreenY + normalizedY * screenRangeY,
    );

    // Clamp
    screenPoint = Offset(
      screenPoint.dx.clamp(0, screenSize.width),
      screenPoint.dy.clamp(0, screenSize.height),
    );

    // Smooth
    final smoothed = _smooth(screenPoint);

    return GazePoint(position: smoothed, confidence: 0.9);
  }

  Offset _smooth(Offset point) {
    _history.add(point);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }

    double sumX = 0, sumY = 0;
    for (final p in _history) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(sumX / _history.length, sumY / _history.length);
  }

  void reset() {
    _calibrationMap.clear();
    _history.clear();
    _isCalibrated = false;
  }
}

class _CalibrationData {
  final Offset eyePosition;
  final Offset screenPosition;

  _CalibrationData({required this.eyePosition, required this.screenPosition});
}