import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'pupil_detector.dart';

class EnhancedGazePoint {
  final Offset position;
  final double confidence;
  final bool usingPupils;

  EnhancedGazePoint({
    required this.position,
    required this.confidence,
    this.usingPupils = false,
  });
}

class EnhancedGazeTracker {
  // Calibration storage
  final List<Offset> _gazePoints = [];
  final List<Offset> _screenPoints = [];
  bool _isCalibrated = false;

  // Smoothing (minimal - like EVA)
  final List<Offset> _history = [];
  final int _historySize = 3;

  // Calibration bounds
  double _minGazeX = 0, _maxGazeX = 1;
  double _minGazeY = 0, _maxGazeY = 1;
  double _minScreenX = 0, _maxScreenX = 1;
  double _minScreenY = 0, _maxScreenY = 1;

  bool get isCalibrated => _isCalibrated;

  List<Offset> getCalibrationPoints(Size screenSize) {
    final marginX = 100.0;
    final marginY = 100.0;

    return [
      Offset(marginX, marginY),
      Offset(screenSize.width / 2, marginY),
      Offset(screenSize.width - marginX, marginY),

      Offset(marginX, screenSize.height / 2),
      Offset(screenSize.width / 2, screenSize.height / 2),
      Offset(screenSize.width - marginX, screenSize.height / 2),

      Offset(marginX, screenSize.height - marginY),
      Offset(screenSize.width / 2, screenSize.height - marginY),
      Offset(screenSize.width - marginX, screenSize.height - marginY),
    ];
  }

  /// Get reference point (triangle or face center)
  Offset _getReferencePoint(Face face, PupilInfo? leftPupil, PupilInfo? rightPupil) {
    // Try triangle centroid if pupils available
    if (leftPupil != null && rightPupil != null) {
      final noseTip = face.landmarks[FaceLandmarkType.noseBase];
      if (noseTip != null) {
        return Offset(
          (leftPupil.pupilCenter.dx + rightPupil.pupilCenter.dx + noseTip.position.x.toDouble()) / 3,
          (leftPupil.pupilCenter.dy + rightPupil.pupilCenter.dy + noseTip.position.y.toDouble()) / 3,
        );
      }
    }

    // Fallback to face center (EVA approach)
    final bbox = face.boundingBox;
    return Offset(
      bbox.left + bbox.width / 2,
      bbox.top + bbox.height / 2,
    );
  }

  void addCalibrationSample(
      int index,
      Face face,
      Offset screenPoint,
      PupilInfo? leftPupil,
      PupilInfo? rightPupil,
      Size imageSize,
      ) {
    final gazePoint = _getReferencePoint(face, leftPupil, rightPupil);

    // Store calibration pair
    if (index >= _gazePoints.length) {
      _gazePoints.add(gazePoint);
      _screenPoints.add(screenPoint);
    } else {
      _gazePoints[index] = gazePoint;
      _screenPoints[index] = screenPoint;
    }

    print('Cal $index: Gaze(${gazePoint.dx.toInt()}, ${gazePoint.dy.toInt()}) → Screen(${screenPoint.dx.toInt()}, ${screenPoint.dy.toInt()})');

    if (_gazePoints.length >= 9) {
      _computeMapping();
    }
  }

  void _computeMapping() {
    if (_gazePoints.length < 9) return;

    // Find min/max bounds (EVA approach)
    _minGazeX = _gazePoints.map((p) => p.dx).reduce(math.min);
    _maxGazeX = _gazePoints.map((p) => p.dx).reduce(math.max);
    _minGazeY = _gazePoints.map((p) => p.dy).reduce(math.min);
    _maxGazeY = _gazePoints.map((p) => p.dy).reduce(math.max);

    _minScreenX = _screenPoints.map((p) => p.dx).reduce(math.min);
    _maxScreenX = _screenPoints.map((p) => p.dx).reduce(math.max);
    _minScreenY = _screenPoints.map((p) => p.dy).reduce(math.min);
    _maxScreenY = _screenPoints.map((p) => p.dy).reduce(math.max);

    // Tighter bounds for more sensitivity
    final gazeRangeX = _maxGazeX - _minGazeX;
    final gazeRangeY = _maxGazeY - _minGazeY;
    _minGazeX -= gazeRangeX * 0.05;  // Changed from 0.1 to 0.05
    _maxGazeX += gazeRangeX * 0.05;
    _minGazeY -= gazeRangeY * 0.05;
    _maxGazeY += gazeRangeY * 0.05;

    _isCalibrated = true;
    print('✓ Calibration complete!');
    print('  Gaze X: ${_minGazeX.toInt()} to ${_maxGazeX.toInt()}');
    print('  Gaze Y: ${_minGazeY.toInt()} to ${_maxGazeY.toInt()}');
    print('  Screen X: ${_minScreenX.toInt()} to ${_maxScreenX.toInt()}');
    print('  Screen Y: ${_minScreenY.toInt()} to ${_maxScreenY.toInt()}');
  }

  EnhancedGazePoint? calculateGaze(
      Face face,
      Size screenSize,
      PupilInfo? leftPupil,
      PupilInfo? rightPupil,
      ) {
    if (!_isCalibrated) return null;

    final gazePoint = _getReferencePoint(face, leftPupil, rightPupil);
    final usingPupils = leftPupil != null && rightPupil != null;

    // Simple linear mapping (EVA approach)
    final gazeRangeX = _maxGazeX - _minGazeX;
    final gazeRangeY = _maxGazeY - _minGazeY;
    final screenRangeX = _maxScreenX - _minScreenX;
    final screenRangeY = _maxScreenY - _minScreenY;

    if (gazeRangeX == 0 || gazeRangeY == 0) return null;

    // Normalize gaze position (0 to 1)
    final normX = (gazePoint.dx - _minGazeX) / gazeRangeX;
    final normY = (gazePoint.dy - _minGazeY) / gazeRangeY;

    // Map to screen coordinates
    final rawX = _minScreenX + normX * screenRangeX;
    final rawY = _minScreenY + normY * screenRangeY;

    // Clamp to screen
    final clampedX = rawX.clamp(0.0, screenSize.width).toDouble();
    final clampedY = rawY.clamp(0.0, screenSize.height).toDouble();

    // Minimal smoothing (3-frame average like EVA)
    final smoothed = _smooth(Offset(clampedX, clampedY));

    return EnhancedGazePoint(
      position: smoothed,
      confidence: usingPupils ? 0.95 : 0.85,
      usingPupils: usingPupils,
    );
  }

  Offset _smooth(Offset point) {
    _history.add(point);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }

    // Simple average (EVA approach)
    double sumX = 0, sumY = 0;
    for (final p in _history) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(sumX / _history.length, sumY / _history.length);
  }

  void reset() {
    _gazePoints.clear();
    _screenPoints.clear();
    _history.clear();
    _isCalibrated = false;
  }
}