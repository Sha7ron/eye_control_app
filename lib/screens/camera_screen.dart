import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../services/face_detector_service.dart';
import '../services/enhanced_gaze_tracker.dart';
import '../services/pupil_detector.dart';
import '../widgets/gaze_cursor_painter.dart';
import 'smart_calibration_screen.dart';
import 'app_selector_with_gaze.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  String _errorMessage = '';

  final FaceDetectorService _faceDetector = FaceDetectorService();
  final EnhancedGazeTracker _gazeTracker = EnhancedGazeTracker();
  final PupilDetector _pupilDetector = PupilDetector();

  List<Face> _faces = [];
  bool _isDetecting = false;
  EnhancedGazePoint? _currentGaze;

  PupilInfo? _leftPupil;
  PupilInfo? _rightPupil;

  bool _needsCalibration = true;
  bool _showCalibration = false;
  List<Offset> _calibrationPoints = [];
  int _faceDetectedFrames = 0;

  int _frameCount = 0;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Camera permission denied';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high, // Higher resolution for better pupil detection
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      _frameCount++;

      // Detect faces
      final faces = await _faceDetector.detectFaces(image);
      final screenSize = MediaQuery.of(context).size;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      PupilInfo? leftPupil;
      PupilInfo? rightPupil;

      // Detect pupils if face found
      if (faces.isNotEmpty) {
        final face = faces.first;

        // Convert camera image to img.Image for pupil detection
        final imgFrame = _convertYUV420ToImage(image);

        if (imgFrame != null) {
          // Get eye regions from ML Kit
          final leftEyeRegion = PupilDetector.getEyeRegion(
            face.landmarks[FaceLandmarkType.leftEye],
            imageSize,
          );
          final rightEyeRegion = PupilDetector.getEyeRegion(
            face.landmarks[FaceLandmarkType.rightEye],
            imageSize,
          );

          // Detect pupils in eye regions
          if (leftEyeRegion != null) {
            leftPupil = _pupilDetector.detectPupilInEye(imgFrame, leftEyeRegion);
          }
          if (rightEyeRegion != null) {
            rightPupil = _pupilDetector.detectPupilInEye(imgFrame, rightEyeRegion);
          }
        }
      }

      // Auto-start calibration when face detected
      if (_needsCalibration && faces.isNotEmpty) {
        _faceDetectedFrames++;

        if (_faceDetectedFrames >= 10 && !_showCalibration) {
          setState(() {
            _calibrationPoints = _gazeTracker.getCalibrationPoints(screenSize);
            _showCalibration = true;
          });
        }
      } else if (_needsCalibration && faces.isEmpty) {
        _faceDetectedFrames = 0;
      }

      // Calculate gaze if calibrated
      EnhancedGazePoint? gaze;
      if (!_needsCalibration && faces.isNotEmpty) {
        gaze = _gazeTracker.calculateGaze(
          faces.first,
          screenSize,
          leftPupil,
          rightPupil,
        );
      }

      setState(() {
        _faces = faces;
        _currentGaze = gaze;
        _leftPupil = leftPupil;
        _rightPupil = rightPupil;
        _debugInfo = 'Frame: $_frameCount | Pupils: ${leftPupil != null && rightPupil != null ? "✓" : "✗"}'
            '${gaze != null && gaze.usingPupils ? " | Mode: PUPIL" : gaze != null ? " | Mode: LANDMARK" : ""}';
      });
    } catch (e) {
      print('Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  img.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final imgData = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yPlane.bytesPerRow + x;
          final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

          if (yIndex >= yPlane.bytes.length ||
              uvIndex >= uPlane.bytes.length ||
              uvIndex >= vPlane.bytes.length) continue;

          final yValue = yPlane.bytes[yIndex];
          final uValue = uPlane.bytes[uvIndex];
          final vValue = vPlane.bytes[uvIndex];

          // YUV to RGB conversion
          final r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255).toInt();
          final g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).clamp(0, 255).toInt();
          final b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255).toInt();

          imgData.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return imgData;
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  void _onPointCalibrated(int index) {
    if (_faces.isNotEmpty) {
      _gazeTracker.addCalibrationSample(
        index,
        _faces.first,
        _calibrationPoints[index],
        _leftPupil,
        _rightPupil,
      );
    }
  }

  void _onCalibrationComplete() {
    setState(() {
      _showCalibration = false;
      _needsCalibration = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Enhanced tracking ready! Using pupil detection.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _recalibrate() {
    setState(() {
      _needsCalibration = true;
      _showCalibration = false;
      _faceDetectedFrames = 0;
    });
    _gazeTracker.reset();
  }

  void _openAppSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSelectorWithGaze(
          gazeStream: Stream.periodic(
            const Duration(milliseconds: 50),
                (_) => _currentGaze?.position,
          ).where((p) => p != null).cast<Offset>(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Eye Control'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized && !_needsCalibration)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _recalibrate,
            ),
          if (_isInitialized && !_needsCalibration)
            IconButton(
              icon: const Icon(Icons.apps),
              onPressed: _openAppSelector,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_errorMessage),
            if (_errorMessage.contains('permission'))
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          child: CameraPreview(_cameraController!),
        ),

        // Draw eye regions and pupils for debugging
        if (!_needsCalibration)
          CustomPaint(
            size: size,
            painter: _PupilDebugPainter(
              leftPupil: _leftPupil,
              rightPupil: _rightPupil,
            ),
          ),

        if (!_needsCalibration && _currentGaze != null)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentGaze!.position,
              confidence: _currentGaze!.confidence,
            ),
          ),

        if (_showCalibration)
          SmartCalibrationScreen(
            points: _calibrationPoints,
            faceDetected: _faces.isNotEmpty,
            onPointCalibrated: _onPointCalibrated,
            onComplete: _onCalibrationComplete,
          ),

        // Enhanced status with pupil info
        if (!_showCalibration)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _faces.isNotEmpty ? Icons.face : Icons.face_outlined,
                        color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _needsCalibration
                              ? (_faceDetectedFrames > 0 ? 'Starting...' : 'Position face')
                              : 'Tracking',
                          style: TextStyle(
                            color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_needsCalibration && _currentGaze != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _currentGaze!.usingPupils
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentGaze!.usingPupils ? 'PUPILS' : 'LANDMARKS',
                            style: TextStyle(
                              color: _currentGaze!.usingPupils ? Colors.green : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_debugInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _debugInfo,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Debug painter to visualize pupils
class _PupilDebugPainter extends CustomPainter {
  final PupilInfo? leftPupil;
  final PupilInfo? rightPupil;

  _PupilDebugPainter({this.leftPupil, this.rightPupil});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw left pupil
    if (leftPupil != null) {
      paint.color = Colors.cyan;
      canvas.drawCircle(
        leftPupil!.pupilCenter,
        leftPupil!.pupilRadius,
        paint,
      );

      // Draw eye region
      paint.color = Colors.cyan.withOpacity(0.3);
      canvas.drawRect(leftPupil!.eyeRegion, paint);
    }

    // Draw right pupil
    if (rightPupil != null) {
      paint.color = Colors.cyan;
      canvas.drawCircle(
        rightPupil!.pupilCenter,
        rightPupil!.pupilRadius,
        paint,
      );

      // Draw eye region
      paint.color = Colors.cyan.withOpacity(0.3);
      canvas.drawRect(rightPupil!.eyeRegion, paint);
    }
  }

  @override
  bool shouldRepaint(_PupilDebugPainter oldDelegate) => true;
}