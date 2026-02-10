import 'dart:ui';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PupilInfo {
  final Offset pupilCenter;
  final double pupilRadius;
  final Rect eyeRegion;

  PupilInfo({
    required this.pupilCenter,
    required this.pupilRadius,
    required this.eyeRegion,
  });
}

class PupilDetector {
  /// Detect pupil within an eye region using OpenCV-style algorithms
  PupilInfo? detectPupilInEye(img.Image frame, Rect eyeRegion) {
    try {
      // Extract eye region
      final eyeImage = img.copyCrop(
        frame,
        x: eyeRegion.left.toInt().clamp(0, frame.width - 1),
        y: eyeRegion.top.toInt().clamp(0, frame.height - 1),
        width: eyeRegion.width.toInt().clamp(1, frame.width),
        height: eyeRegion.height.toInt().clamp(1, frame.height),
      );

      // Convert to grayscale
      final grayEye = img.grayscale(eyeImage);

      // Apply Gaussian blur to reduce noise
      final blurred = _gaussianBlur(grayEye, 3);

      // Find darkest region (pupil is darkest part)
      final pupilLocal = _findDarkestRegion(blurred);

      if (pupilLocal == null) return null;

      // Convert back to frame coordinates
      final pupilGlobal = Offset(
        eyeRegion.left + pupilLocal.dx,
        eyeRegion.top + pupilLocal.dy,
      );

      return PupilInfo(
        pupilCenter: pupilGlobal,
        pupilRadius: eyeRegion.width * 0.15, // Approximate
        eyeRegion: eyeRegion,
      );
    } catch (e) {
      print('Pupil detection error: $e');
      return null;
    }
  }

  /// Apply Gaussian blur
  img.Image _gaussianBlur(img.Image image, int radius) {
    // Simple box blur approximation
    final blurred = img.Image.from(image);

    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        int sum = 0;
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final pixel = image.getPixel(x + dx, y + dy);
            sum += pixel.r.toInt();
            count++;
          }
        }

        final avg = sum ~/ count;
        blurred.setPixelRgba(x, y, avg, avg, avg, 255);
      }
    }

    return blurred;
  }

  /// Find darkest region (pupil) in the eye
  Offset? _findDarkestRegion(img.Image grayImage) {
    // Focus on center region (pupil is usually centered)
    final centerX = grayImage.width ~/ 2;
    final centerY = grayImage.height ~/ 2;
    final searchRadius = (grayImage.width * 0.4).toInt();

    int minBrightness = 255;
    int darkestX = centerX;
    int darkestY = centerY;

    for (int y = math.max(0, centerY - searchRadius);
    y < math.min(grayImage.height, centerY + searchRadius);
    y++) {
      for (int x = math.max(0, centerX - searchRadius);
      x < math.min(grayImage.width, centerX + searchRadius);
      x++) {
        final pixel = grayImage.getPixel(x, y);
        final brightness = pixel.r.toInt();

        if (brightness < minBrightness) {
          minBrightness = brightness;
          darkestX = x;
          darkestY = y;
        }
      }
    }

    // Verify we found something reasonably dark
    if (minBrightness > 100) return null; // Too bright, probably not a pupil

    return Offset(darkestX.toDouble(), darkestY.toDouble());
  }

  /// Get eye region from ML Kit landmarks
  static Rect? getEyeRegion(FaceLandmark? eyeLandmark, Size imageSize) {
    if (eyeLandmark == null) return null;

    final eyePos = eyeLandmark.position;

    // Eye region is approximately 60x40 pixels around the landmark
    final width = imageSize.width * 0.15;
    final height = imageSize.height * 0.08;

    final left = (eyePos.x - width / 2).clamp(0.0, imageSize.width - width);
    final top = (eyePos.y - height / 2).clamp(0.0, imageSize.height - height);

    return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
  }
}