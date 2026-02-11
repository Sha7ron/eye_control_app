import 'dart:ui';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PupilInfo {
  final Offset pupilCenter;
  final double pupilRadius;
  final Rect eyeRegion;
  final double confidence;

  PupilInfo({
    required this.pupilCenter,
    required this.pupilRadius,
    required this.eyeRegion,
    required this.confidence,
  });
}

class PupilDetector {
  Offset? _prevLeftPupil;
  Offset? _prevRightPupil;
  final double _maxJumpDistance = 40.0;

  /// Detect pupil directly from camera Y plane (grayscale luminance)
  PupilInfo? detectPupilInEye(CameraImage cameraImage, Rect eyeRegion, bool isLeftEye) {
    try {
      final yPlane = cameraImage.planes[0];
      final yBytes = yPlane.bytes;
      final width = cameraImage.width;
      final height = cameraImage.height;
      final bytesPerRow = yPlane.bytesPerRow;

      // Validate and clamp eye region
      final eyeLeft = eyeRegion.left.toInt().clamp(0, width - 1);
      final eyeTop = eyeRegion.top.toInt().clamp(0, height - 1);
      final eyeRight = eyeRegion.right.toInt().clamp(eyeLeft + 1, width);
      final eyeBottom = eyeRegion.bottom.toInt().clamp(eyeTop + 1, height);

      if (eyeRight <= eyeLeft || eyeBottom <= eyeTop) return null;

      // Calculate adaptive threshold with contrast analysis
      int minBrightness = 255;
      int maxBrightness = 0;
      int avgBrightness = 0;
      int pixelCount = 0;

      for (int y = eyeTop; y < eyeBottom; y += 2) {
        for (int x = eyeLeft; x < eyeRight; x += 2) {
          final index = y * bytesPerRow + x;
          if (index < yBytes.length) {
            final brightness = yBytes[index];
            avgBrightness += brightness;
            minBrightness = math.min(minBrightness, brightness);
            maxBrightness = math.max(maxBrightness, brightness);
            pixelCount++;
          }
        }
      }

      if (pixelCount == 0) return null;
      avgBrightness ~/= pixelCount;

      // Adaptive threshold based on contrast
      final contrast = maxBrightness - minBrightness;
      final threshold = contrast > 50
          ? minBrightness + (contrast * 0.4).toInt()  // High contrast
          : (avgBrightness * 0.5).toInt();  // Low contrast

      // Find center of mass of dark pixels (pupil detection)
      double sumX = 0;
      double sumY = 0;
      int darkPixelCount = 0;
      int darkestBrightness = 255;

      // First pass - find darkest pixels
      for (int y = eyeTop; y < eyeBottom; y++) {
        for (int x = eyeLeft; x < eyeRight; x++) {
          final index = y * bytesPerRow + x;
          if (index >= yBytes.length) continue;

          final brightness = yBytes[index];

          if (brightness < threshold) {
            darkestBrightness = math.min(darkestBrightness, brightness);
          }
        }
      }

      // Second pass - calculate weighted center of mass
      for (int y = eyeTop; y < eyeBottom; y++) {
        for (int x = eyeLeft; x < eyeRight; x++) {
          final index = y * bytesPerRow + x;
          if (index >= yBytes.length) continue;

          final brightness = yBytes[index];

          if (brightness < threshold) {
            // Weight by darkness (darker = higher weight)
            final weight = (threshold - brightness).toDouble();
            sumX += x * weight;
            sumY += y * weight;
            darkPixelCount += weight.toInt();
          }
        }
      }

      if (darkPixelCount < 10) return null; // Need minimum dark region

      final pupilX = sumX / darkPixelCount;
      final pupilY = sumY / darkPixelCount;

      // Verify pupil is within reasonable bounds (center 80% of eye region)
      final eyeCenterX = (eyeLeft + eyeRight) / 2;
      final eyeCenterY = (eyeTop + eyeBottom) / 2;
      final maxDistanceFromCenter = math.min(eyeRegion.width, eyeRegion.height) * 0.4;

      final distanceFromCenter = math.sqrt(
          math.pow(pupilX - eyeCenterX, 2) + math.pow(pupilY - eyeCenterY, 2)
      );

      if (distanceFromCenter > maxDistanceFromCenter) {
        // Pupil too far from center, probably noise
        return null;
      }

      final pupilCenter = Offset(pupilX, pupilY);

      // Outlier rejection - prevent sudden jumps
      final prevPupil = isLeftEye ? _prevLeftPupil : _prevRightPupil;
      if (prevPupil != null) {
        final distance = (pupilCenter - prevPupil).distance;
        if (distance > _maxJumpDistance) {
          // Interpolate to prevent jumps
          final interpolated = Offset(
            prevPupil.dx * 0.7 + pupilCenter.dx * 0.3,
            prevPupil.dy * 0.7 + pupilCenter.dy * 0.3,
          );

          if (isLeftEye) {
            _prevLeftPupil = interpolated;
          } else {
            _prevRightPupil = interpolated;
          }

          return PupilInfo(
            pupilCenter: interpolated,
            pupilRadius: eyeRegion.width * 0.15,
            eyeRegion: eyeRegion,
            confidence: 0.6, // Lower confidence for interpolated
          );
        }
      }

      // Update previous position
      if (isLeftEye) {
        _prevLeftPupil = pupilCenter;
      } else {
        _prevRightPupil = pupilCenter;
      }

      // Calculate confidence based on contrast and detection quality
      double confidence = 0.95;
      if (contrast < 30) {
        confidence = 0.7; // Low contrast = lower confidence
      } else if (darkPixelCount < 20) {
        confidence = 0.8; // Small pupil region = lower confidence
      }

      return PupilInfo(
        pupilCenter: pupilCenter,
        pupilRadius: eyeRegion.width * 0.15,
        eyeRegion: eyeRegion,
        confidence: confidence,
      );
    } catch (e) {
      print('Pupil detection error: $e');
      return null;
    }
  }

  /// Get eye region from ML Kit landmarks
  static Rect? getEyeRegion(FaceLandmark? eyeLandmark, Size imageSize) {
    if (eyeLandmark == null) return null;

    final eyePos = eyeLandmark.position;

    // Eye region - 20% of image width, 12% of image height
    final width = imageSize.width * 0.20;
    final height = imageSize.height * 0.12;

    final left = (eyePos.x - width / 2).clamp(0.0, imageSize.width - width);
    final top = (eyePos.y - height / 2).clamp(0.0, imageSize.height - height);

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Reset tracking state
  void reset() {
    _prevLeftPupil = null;
    _prevRightPupil = null;
  }
}