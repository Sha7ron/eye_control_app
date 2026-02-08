import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraImageConverter {
  static Map<String, dynamic> convertCameraImageToJpeg(CameraImage cameraImage) {
    try {
      final convertedImage = _convertYUV420(cameraImage);
      final jpegBytes = Uint8List.fromList(img.encodeJpg(convertedImage, quality: 90));

      return {
        'bytes': jpegBytes,
        'width': convertedImage.width,
        'height': convertedImage.height,
      };
    } catch (e) {
      print('Error converting camera image: $e');
      rethrow;
    }
  }

  // Keep the old method for backward compatibility
  static Uint8List convertCameraImageToBytes(CameraImage cameraImage) {
    final result = convertCameraImageToJpeg(cameraImage);
    return result['bytes'] as Uint8List;
  }

  static img.Image _convertYUV420(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final img.Image image = img.Image(width: width, height: height);

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return image;
  }
}