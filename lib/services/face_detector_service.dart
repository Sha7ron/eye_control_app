import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: false,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<List<Face>> detectFaces(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return [];

      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final BytesBuilder allBytes = BytesBuilder();
      for (final Plane plane in image.planes) {
        allBytes.add(plane.bytes);
      }
      final bytes = allBytes.toBytes();

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}