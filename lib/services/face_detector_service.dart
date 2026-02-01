import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector;

  FaceDetectorService()
      : _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  Future<List<Face>> detectFaces(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      print('Processed image: ${image.width}x${image.height}, found ${faces.length} faces');
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    // Concatenate all plane bytes
    final allBytes = <int>[];
    for (final plane in image.planes) {
      allBytes.addAll(plane.bytes);
    }
    final bytes = Uint8List.fromList(allBytes);

    // Determine the image format and rotation based on platform
    final InputImageFormat format;
    final InputImageRotation rotation;

    if (Platform.isAndroid) {
      format = InputImageFormat.nv21;
      rotation = InputImageRotation.rotation270deg;
    } else if (Platform.isIOS) {
      format = InputImageFormat.bgra8888;
      rotation = InputImageRotation.rotation0deg;
    } else {
      format = InputImageFormat.nv21;
      rotation = InputImageRotation.rotation0deg;
    }

    // Create metadata
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    print('Image metadata: ${image.width}x${image.height}, format: $format, rotation: $rotation');

    // Create and return InputImage
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  void dispose() {
    _faceDetector.close();
  }
}