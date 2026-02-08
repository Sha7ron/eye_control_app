import 'dart:ui';
import 'dart:math' as math;
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
  // Motion history for velocity-based smoothing (like optical flow)
  final List<Offset> _motionHistory = [];
  final List<Offset> _gazeHistory = [];
  final int _motionHistorySize = 3;
  final int _gazeHistorySize = 8;

  // Reference tracking (EVA style)
  Offset? _referenceFaceCenter;
  List<Offset>? _referenceLandmarks; // Multiple tracking points
  double? _referenceFaceWidth;
  Size? _referenceScreenSize;

  // Sensitivity (EVA uses 2.0-4.0 range)
  double _sensitivityX = 3.0;
  double _sensitivityY = 3.0;

  // Dead zone (prevents micro-jitter)
  final double _deadZoneRadius = 3.0;

  // Velocity damping (smooths sudden movements)
  double _velocityDamping = 0.7;

  // Distance compensation
  bool _useDistanceCompensation = true;

  void setScreenSize(Size size) {
    _referenceScreenSize = size;
  }

  void calibrate(Face face, Size imageSize, Size screenSize) {
    // EVA approach: Store multiple landmark points for robust tracking
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];

    _referenceLandmarks = [];

    if (leftEye != null && rightEye != null && nose != null) {
      // Store multiple reference points (EVA style)
      _referenceLandmarks!.add(Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble()));
      _referenceLandmarks!.add(Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble()));
      _referenceLandmarks!.add(Offset(nose.position.x.toDouble(), nose.position.y.toDouble()));

      // Calculate weighted center
      _referenceFaceCenter = Offset(
        (_referenceLandmarks![0].dx + _referenceLandmarks![1].dx + _referenceLandmarks![2].dx) / 3,
        (_referenceLandmarks![0].dy + _referenceLandmarks![1].dy + _referenceLandmarks![2].dy) / 3,
      );

      _referenceFaceWidth = (rightEye.position.x - leftEye.position.x).toDouble();
    } else {
      // Fallback to face center
      _referenceFaceCenter = Offset(
        face.boundingBox.left + face.boundingBox.width / 2,
        face.boundingBox.top + face.boundingBox.height / 2,
      );
      _referenceFaceWidth = face.boundingBox.width;
    }

    _referenceScreenSize = screenSize;
    _gazeHistory.clear();
    _motionHistory.clear();

    print('✓ Calibrated with ${_referenceLandmarks?.length ?? 0} tracking points');
  }

  bool get isCalibrated => _referenceFaceCenter != null;

  GazeData? calculateGaze(Face face, Size imageSize, Size screenSize) {
    if (_referenceScreenSize == null) {
      _referenceScreenSize = screenSize;
    }

    if (_referenceFaceCenter == null) {
      return null;
    }

    // Calculate current position using same landmarks
    Offset currentFaceCenter;
    double currentFaceWidth;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];

    if (leftEye != null && rightEye != null && nose != null) {
      // Use same weighted average as calibration
      currentFaceCenter = Offset(
        (leftEye.position.x + rightEye.position.x + nose.position.x.toDouble()) / 3,
        (leftEye.position.y + rightEye.position.y + nose.position.y.toDouble()) / 3,
      );
      currentFaceWidth = (rightEye.position.x - leftEye.position.x).toDouble();
    } else {
      currentFaceCenter = Offset(
        face.boundingBox.left + face.boundingBox.width / 2,
        face.boundingBox.top + face.boundingBox.height / 2,
      );
      currentFaceWidth = face.boundingBox.width;
    }

    // Calculate displacement (EVA's core calculation)
    double deltaX = currentFaceCenter.dx - _referenceFaceCenter!.dx;
    double deltaY = currentFaceCenter.dy - _referenceFaceCenter!.dy;

    // Distance compensation (EVA adjusts for head distance changes)
    double distanceCompensation = 1.0;
    if (_useDistanceCompensation && _referenceFaceWidth != null && _referenceFaceWidth! > 0) {
      distanceCompensation = _referenceFaceWidth! / currentFaceWidth;
      distanceCompensation = distanceCompensation.clamp(0.7, 1.5);
    }

    // Dead zone (EVA uses this to prevent jitter)
    final movementMagnitude = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    if (movementMagnitude < _deadZoneRadius) {
      deltaX = 0;
      deltaY = 0;
    }

    // Store motion vector for velocity-based smoothing
    _motionHistory.add(Offset(deltaX, deltaY));
    if (_motionHistory.length > _motionHistorySize) {
      _motionHistory.removeAt(0);
    }

    // Calculate average motion (optical flow approximation)
    Offset avgMotion = Offset.zero;
    if (_motionHistory.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final motion in _motionHistory) {
        sumX += motion.dx;
        sumY += motion.dy;
      }
      avgMotion = Offset(sumX / _motionHistory.length, sumY / _motionHistory.length);
    }

    // Apply velocity damping (EVA smoothing technique)
    deltaX = avgMotion.dx * _velocityDamping;
    deltaY = avgMotion.dy * _velocityDamping;

    // Apply sensitivity with distance compensation
    final adjustedSensitivityX = _sensitivityX * distanceCompensation;
    final adjustedSensitivityY = _sensitivityY * distanceCompensation;

    // Map to screen coordinates (EVA's coordinate transformation)
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;

    // Invert X for natural movement (move head right → cursor moves right)
    Offset gazePoint = Offset(
      screenCenterX - (deltaX * adjustedSensitivityX),
      screenCenterY + (deltaY * adjustedSensitivityY),
    );

    // Clamp to screen bounds
    gazePoint = Offset(
      gazePoint.dx.clamp(0, screenSize.width),
      gazePoint.dy.clamp(0, screenSize.height),
    );

    // Final exponential smoothing (EVA's last smoothing stage)
    final smoothedGaze = _applyExponentialSmoothing(gazePoint);
    final confidence = 0.95;

    return GazeData(
      gazePoint: smoothedGaze,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  Offset _applyExponentialSmoothing(Offset point) {
    _gazeHistory.add(point);
    if (_gazeHistory.length > _gazeHistorySize) {
      _gazeHistory.removeAt(0);
    }

    if (_gazeHistory.isEmpty) return point;

    // Exponential moving average (higher weight to recent points)
    double weightedX = 0;
    double weightedY = 0;
    double totalWeight = 0;

    for (int i = 0; i < _gazeHistory.length; i++) {
      final weight = math.pow(1.6, i).toDouble(); // Slightly more aggressive than before
      final p = _gazeHistory[i];

      weightedX += p.dx * weight;
      weightedY += p.dy * weight;
      totalWeight += weight;
    }

    return Offset(weightedX / totalWeight, weightedY / totalWeight);
  }

  void setSensitivity(double x, double y) {
    _sensitivityX = x;
    _sensitivityY = y;
  }

  void setVelocityDamping(double damping) {
    _velocityDamping = damping.clamp(0.1, 1.0);
  }

  void setDistanceCompensation(bool enabled) {
    _useDistanceCompensation = enabled;
  }

  void reset() {
    _gazeHistory.clear();
    _motionHistory.clear();
    _referenceFaceCenter = null;
    _referenceLandmarks = null;
    _referenceFaceWidth = null;
  }

  // Getters
  double get sensitivityX => _sensitivityX;
  double get sensitivityY => _sensitivityY;
  double get velocityDamping => _velocityDamping;
  bool get distanceCompensationEnabled => _useDistanceCompensation;
}