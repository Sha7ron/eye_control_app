import 'dart:typed_data';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:camera/camera.dart';

class IrisDetectorService {
  final FaceDetector _detector = FaceDetector();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use frontCamera model for selfie/front camera use
      await _detector.initialize(model: FaceDetectionModel.frontCamera);
      _isInitialized = true;
      print('✓ Iris detector initialized');
    } catch (e) {
      print('✗ Error initializing iris detector: $e');
      rethrow;
    }
  }

  Future<List<Face>> detectFaces(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('Detector not initialized. Call initialize() first.');
    }

    try {
      // Use full mode to get iris tracking data
      final faces = await _detector.detectFaces(
        imageBytes,
        mode: FaceDetectionMode.full,
      );
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  void dispose() {
    _detector.dispose();
  }
}