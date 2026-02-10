import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'pupil_detector.dart';

class EnhancedGazePoint {
  final Offset position;
  final double confidence;
  final bool usingPupils; // Whether we're using pupil data or fallback

  EnhancedGazePoint({
    required this.position,
    required this.confidence,
    this.usingPupils = false,
  });
}

class EnhancedGazeTracker {
  final Map<int, _CalibrationData> _calibrationMap = {};
  bool _isCalibrated = false;

  final List<Offset> _history = [];
  final int _historySize = 4;

  double _minGazeX = 0, _maxGazeX = 0;
  double _minGazeY = 0, _maxGazeY = 0;
  double _minScreenX = 0, _maxScreenX = 0;
  double _minScreenY = 0, _maxScreenY = 0;

  bool get isCalibrated => _isCalibrated;

  List<Offset> getCalibrationPoints(Size screenSize) {
    final margin = 80.0;
    return [
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

  void addCalibrationSample(
      int index,
      Face face,
      Offset screenPoint,
      PupilInfo? leftPupil,
      PupilInfo? rightPupil,
      ) {
    Offset gazeVector;
    bool usedPupils = false;

    if (leftPupil != null && rightPupil != null) {
      // Use pupil centers (BEST accuracy)
      gazeVector = Offset(
        (leftPupil.pupilCenter.dx + rightPupil.pupilCenter.dx) / 2,
        (leftPupil.pupilCenter.dy + rightPupil.pupilCenter.dy) / 2,
      );
      usedPupils = true;
      print('✓ Using PUPILS for calibration $index');
    } else {
      // Fallback to eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye == null || rightEye == null) return;

      gazeVector = Offset(
        (leftEye.position.x + rightEye.position.x) / 2,
        (leftEye.position.y + rightEye.position.y) / 2,
      );
      print('⚠ Using landmarks for calibration $index (pupil detection failed)');
    }

    _calibrationMap[index] = _CalibrationData(
      gazeVector: gazeVector,
      screenPosition: screenPoint,
      usedPupils: usedPupils,
    );

    if (_calibrationMap.length >= 9) {
      _computeMapping();
    }
  }

  void _computeMapping() {
    if (_calibrationMap.length < 9) return;

    _minGazeX = double.infinity;
    _maxGazeX = double.negativeInfinity;
    _minGazeY = double.infinity;
    _maxGazeY = double.negativeInfinity;
    _minScreenX = double.infinity;
    _maxScreenX = double.negativeInfinity;
    _minScreenY = double.infinity;
    _maxScreenY = double.negativeInfinity;

    int pupilCount = 0;
    _calibrationMap.forEach((_, data) {
      _minGazeX = math.min(_minGazeX, data.gazeVector.dx);
      _maxGazeX = math.max(_maxGazeX, data.gazeVector.dx);
      _minGazeY = math.min(_minGazeY, data.gazeVector.dy);
      _maxGazeY = math.max(_maxGazeY, data.gazeVector.dy);

      _minScreenX = math.min(_minScreenX, data.screenPosition.dx);
      _maxScreenX = math.max(_maxScreenX, data.screenPosition.dx);
      _minScreenY = math.min(_minScreenY, data.screenPosition.dy);
      _maxScreenY = math.max(_maxScreenY, data.screenPosition.dy);

      if (data.usedPupils) pupilCount++;
    });

    _isCalibrated = true;
    print('✓ Calibration: $pupilCount/9 points used pupil data');
  }

  EnhancedGazePoint? calculateGaze(
      Face face,
      Size screenSize,
      PupilInfo? leftPupil,
      PupilInfo? rightPupil,
      ) {
    if (!_isCalibrated) return null;

    Offset gazeVector;
    bool usingPupils = false;

    if (leftPupil != null && rightPupil != null) {
      // Use pupil centers for best accuracy
      gazeVector = Offset(
        (leftPupil.pupilCenter.dx + rightPupil.pupilCenter.dx) / 2,
        (leftPupil.pupilCenter.dy + rightPupil.pupilCenter.dy) / 2,
      );
      usingPupils = true;
    } else {
      // Fallback to eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye == null || rightEye == null) return null;

      gazeVector = Offset(
        (leftEye.position.x + rightEye.position.x) / 2,
        (leftEye.position.y + rightEye.position.y) / 2,
      );
    }

    // Map to screen
    final gazeRangeX = _maxGazeX - _minGazeX;
    final gazeRangeY = _maxGazeY - _minGazeY;
    final screenRangeX = _maxScreenX - _minScreenX;
    final screenRangeY = _maxScreenY - _minScreenY;

    if (gazeRangeX == 0 || gazeRangeY == 0) return null;

    final normalizedX = (gazeVector.dx - _minGazeX) / gazeRangeX;
    final normalizedY = (gazeVector.dy - _minGazeY) / gazeRangeY;

    Offset screenPoint = Offset(
      _minScreenX + normalizedX * screenRangeX,
      _minScreenY + normalizedY * screenRangeY,
    );

    screenPoint = Offset(
      screenPoint.dx.clamp(0, screenSize.width),
      screenPoint.dy.clamp(0, screenSize.height),
    );

    final smoothed = _smooth(screenPoint);

    return EnhancedGazePoint(
      position: smoothed,
      confidence: usingPupils ? 0.95 : 0.8,
      usingPupils: usingPupils,
    );
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
  final Offset gazeVector;
  final Offset screenPosition;
  final bool usedPupils;

  _CalibrationData({
    required this.gazeVector,
    required this.screenPosition,
    required this.usedPupils,
  });
}