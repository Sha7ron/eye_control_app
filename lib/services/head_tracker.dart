import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class HeadPoint {
  final Offset position;
  final double confidence;

  HeadPoint({
    required this.position,
    required this.confidence,
  });
}

class HeadTracker {
  // Calibration data
  Offset? _centerPosition;
  double _movementScale = 2.5; // Sensitivity multiplier

  // Smoothing
  final List<Offset> _history = [];
  final int _historySize = 3;

  // Screen size
  Size? _screenSize;

  bool _isCalibrated = false;
  bool get isCalibrated => _isCalibrated;

  /// Calibrate - store center position
  void calibrate(Face face, Size screenSize) {
    _screenSize = screenSize;

    // Store center reference (face bounding box center)
    final bbox = face.boundingBox;
    _centerPosition = Offset(
      bbox.left + bbox.width / 2,
      bbox.top + bbox.height / 2,
    );

    _isCalibrated = true;
    _history.clear();

    print('✓ HEAD TRACKING calibrated at: (${_centerPosition!.dx.toInt()}, ${_centerPosition!.dy.toInt()})');
    print('  Screen size: ${screenSize.width.toInt()} x ${screenSize.height.toInt()}');
  }

  /// Calculate cursor position from head movement
  HeadPoint? calculatePosition(Face face) {
    if (!_isCalibrated || _centerPosition == null || _screenSize == null) {
      return null;
    }

    // Get current face center
    final bbox = face.boundingBox;
    final currentPosition = Offset(
      bbox.left + bbox.width / 2,
      bbox.top + bbox.height / 2,
    );

    // Calculate movement from calibration center
    final deltaX = currentPosition.dx - _centerPosition!.dx;
    final deltaY = currentPosition.dy - _centerPosition!.dy;

    // Map to screen coordinates
    // IMPORTANT: Front camera is MIRRORED, so we INVERT X-axis
    final screenCenterX = _screenSize!.width / 2;
    final screenCenterY = _screenSize!.height / 2;

    // Apply movement with sensitivity (INVERT X for mirror correction)
    final screenX = screenCenterX - (deltaX * _movementScale); // Note the MINUS
    final screenY = screenCenterY + (deltaY * _movementScale); // Plus for Y

    // Clamp to screen bounds
    final clampedX = screenX.clamp(0.0, _screenSize!.width).toDouble();
    final clampedY = screenY.clamp(0.0, _screenSize!.height).toDouble();

    // Smooth
    final smoothed = _smooth(Offset(clampedX, clampedY));

    return HeadPoint(
      position: smoothed,
      confidence: 0.95,
    );
  }

  Offset _smooth(Offset point) {
    _history.add(point);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }

    // Simple average
    double sumX = 0, sumY = 0;
    for (final p in _history) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(sumX / _history.length, sumY / _history.length);
  }

  /// Adjust sensitivity (1.0 - 5.0)
  void setSensitivity(double sensitivity) {
    _movementScale = sensitivity.clamp(1.0, 5.0);
    print('Sensitivity set to: $_movementScale');
  }

  void reset() {
    _centerPosition = null;
    _history.clear();
    _isCalibrated = false;
  }
}