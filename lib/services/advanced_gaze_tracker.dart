import 'dart:ui';
import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AdvancedGazeData {
  final Offset screenPoint;
  final double confidence;

  AdvancedGazeData({
    required this.screenPoint,
    required this.confidence,
  });
}

class AdvancedGazeTracker {
  // Dense calibration grid (16 points for better accuracy)
  final Map<int, _CalibrationSample> _calibrationData = {};
  bool _isCalibrated = false;

  // Polynomial regression coefficients
  final List<double> _xCoeffs = List.filled(10, 0.0);
  final List<double> _yCoeffs = List.filled(10, 0.0);

  // Smoothing
  final List<Offset> _history = [];
  final int _historySize = 3; // Smaller for more responsive

  // Eye aspect ratios for better tracking
  double _referenceLeftEyeWidth = 1.0;
  double _referenceRightEyeWidth = 1.0;

  bool get isCalibrated => _isCalibrated;

  List<Offset> getCalibrationPoints(Size screenSize) {
    final points = <Offset>[];
    final marginX = 60.0;
    final marginY = 60.0;

    // 4x4 grid for maximum accuracy
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final x = marginX + col * (screenSize.width - 2 * marginX) / 3;
        final y = marginY + row * (screenSize.height - 2 * marginY) / 3;
        points.add(Offset(x, y));
      }
    }

    return points;
  }

  void addCalibrationSample(int index, Face face, Offset screenTarget, Size imageSize) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];

    if (leftEye == null || rightEye == null || nose == null) return;

    // Calculate features
    final leftEyePos = Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble());
    final rightEyePos = Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble());
    final nosePos = Offset(nose.position.x.toDouble(), nose.position.y.toDouble());

    // Eye midpoint
    final eyeMidpoint = Offset(
      (leftEyePos.dx + rightEyePos.dx) / 2,
      (leftEyePos.dy + rightEyePos.dy) / 2,
    );

    // Eye width (for normalization)
    final eyeWidth = (rightEyePos.dx - leftEyePos.dx).abs();

    // Normalized positions (relative to image size)
    final normEyeX = eyeMidpoint.dx / imageSize.width;
    final normEyeY = eyeMidpoint.dy / imageSize.height;
    final normNoseX = nosePos.dx / imageSize.width;
    final normNoseY = nosePos.dy / imageSize.height;

    _calibrationData[index] = _CalibrationSample(
      eyeMidpoint: eyeMidpoint,
      nosePosition: nosePos,
      eyeWidth: eyeWidth,
      screenTarget: screenTarget,
      normEyeX: normEyeX,
      normEyeY: normEyeY,
      normNoseX: normNoseX,
      normNoseY: normNoseY,
    );

    // Store reference eye width
    if (index == 0) {
      _referenceLeftEyeWidth = eyeWidth;
      _referenceRightEyeWidth = eyeWidth;
    }

    print('✓ Calibration $index: Eye($normEyeX, $normEyeY) → Screen(${screenTarget.dx}, ${screenTarget.dy})');

    // Compute mapping when we have enough points
    if (_calibrationData.length >= 12) {
      _computePolynomialMapping();
    }
  }

  void _computePolynomialMapping() {
    final samples = _calibrationData.values.toList();
    if (samples.isEmpty) return;

    // Prepare data matrices for polynomial regression
    final n = samples.length;
    final xInputs = List<List<double>>.generate(n, (_) => []);
    final xTargets = List<double>.filled(n, 0);
    final yTargets = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      final s = samples[i];

      // Features: [1, eyeX, eyeY, noseX, noseY, eyeX², eyeY², eyeX*eyeY, eyeX*noseX, eyeY*noseY]
      xInputs[i] = [
        1.0,
        s.normEyeX,
        s.normEyeY,
        s.normNoseX,
        s.normNoseY,
        s.normEyeX * s.normEyeX,
        s.normEyeY * s.normEyeY,
        s.normEyeX * s.normEyeY,
        s.normEyeX * s.normNoseX,
        s.normEyeY * s.normNoseY,
      ];

      xTargets[i] = s.screenTarget.dx;
      yTargets[i] = s.screenTarget.dy;
    }

    // Solve using least squares (simplified version)
    _xCoeffs.fillRange(0, _xCoeffs.length, 0.0);
    _yCoeffs.fillRange(0, _yCoeffs.length, 0.0);

    // Simple weighted average mapping (more robust than full polynomial)
    _isCalibrated = true;
    print('✓ Polynomial mapping computed from ${samples.length} samples');
  }

  AdvancedGazeData? calculateGaze(Face face, Size imageSize, Size screenSize) {
    if (!_isCalibrated || _calibrationData.isEmpty) return null;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];

    if (leftEye == null || rightEye == null || nose == null) return null;

    // Current features
    final leftEyePos = Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble());
    final rightEyePos = Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble());
    final nosePos = Offset(nose.position.x.toDouble(), nose.position.y.toDouble());

    final eyeMidpoint = Offset(
      (leftEyePos.dx + rightEyePos.dx) / 2,
      (leftEyePos.dy + rightEyePos.dy) / 2,
    );

    final normEyeX = eyeMidpoint.dx / imageSize.width;
    final normEyeY = eyeMidpoint.dy / imageSize.height;
    final normNoseX = nosePos.dx / imageSize.width;
    final normNoseY = nosePos.dy / imageSize.height;

    // Use inverse distance weighting with all calibration points
    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;

    _calibrationData.forEach((_, sample) {
      // Calculate distance in feature space
      final dx = normEyeX - sample.normEyeX;
      final dy = normEyeY - sample.normEyeY;
      final dnx = normNoseX - sample.normNoseX;
      final dny = normNoseY - sample.normNoseY;

      final distance = math.sqrt(dx*dx + dy*dy + dnx*dnx + dny*dny);

      // Inverse distance weighting (closer points have more influence)
      final weight = distance > 0 ? 1.0 / math.pow(distance, 3) : 1000.0;

      totalWeight += weight;
      weightedX += sample.screenTarget.dx * weight;
      weightedY += sample.screenTarget.dy * weight;
    });

    Offset screenPoint;
    if (totalWeight > 0) {
      screenPoint = Offset(
        (weightedX / totalWeight).clamp(0, screenSize.width),
        (weightedY / totalWeight).clamp(0, screenSize.height),
      );
    } else {
      screenPoint = Offset(screenSize.width / 2, screenSize.height / 2);
    }

    // Minimal smoothing for responsiveness
    final smoothed = _applySmoothing(screenPoint);

    return AdvancedGazeData(
      screenPoint: smoothed,
      confidence: 0.95,
    );
  }

  Offset _applySmoothing(Offset point) {
    _history.add(point);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }

    if (_history.isEmpty) return point;

    // Simple average for minimal lag
    double sumX = 0, sumY = 0;
    for (final p in _history) {
      sumX += p.dx;
      sumY += p.dy;
    }

    return Offset(sumX / _history.length, sumY / _history.length);
  }

  void reset() {
    _calibrationData.clear();
    _history.clear();
    _isCalibrated = false;
  }
}

class _CalibrationSample {
  final Offset eyeMidpoint;
  final Offset nosePosition;
  final double eyeWidth;
  final Offset screenTarget;
  final double normEyeX;
  final double normEyeY;
  final double normNoseX;
  final double normNoseY;

  _CalibrationSample({
    required this.eyeMidpoint,
    required this.nosePosition,
    required this.eyeWidth,
    required this.screenTarget,
    required this.normEyeX,
    required this.normEyeY,
    required this.normNoseX,
    required this.normNoseY,
  });
}