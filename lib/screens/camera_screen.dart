import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../services/gaze_tracker.dart';
import '../widgets/face_detector_painter.dart';
import '../widgets/gaze_cursor_painter.dart';
import 'settings_screen.dart';
import 'app_selector_with_gaze.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  String _errorMessage = '';

  // Face detection
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  final GazeTracker _gazeTracker = GazeTracker();
  List<Face> _faces = [];
  bool _isDetecting = false;
  Size? _imageSize;
  int _frameCount = 0;
  String _debugInfo = '';
  CameraDescription? _camera;

  // Gaze tracking
  GazeData? _currentGaze;

  // Auto-calibration state
  bool _needsCalibration = true;
  bool _showCalibrationInstructions = true;
  int _faceDetectedFrames = 0;
  static const int _requiredStableFrames = 30; // ~1 second of stable detection

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
        _errorMessage = 'Camera permission required';
      });
      return;
    }

    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found';
        });
        return;
      }

      _camera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isInitialized = true;
        _debugInfo = '✓ Ready';
      });

      print('✓ Camera initialized');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
      print('✗ Error: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      _frameCount++;

      final faces = await _faceDetectorService.detectFaces(image);
      final screenSize = MediaQuery.of(context).size;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Auto-calibration logic
      if (_needsCalibration && faces.isNotEmpty) {
        final face = faces.first;
        final faceSize = face.boundingBox.width * face.boundingBox.height;
        final imageArea = imageSize.width * imageSize.height;
        final faceRatio = faceSize / imageArea;

        // Check if face is at good distance (10-25% of image)
        if (faceRatio > 0.10 && faceRatio < 0.25) {
          _faceDetectedFrames++;

          if (_faceDetectedFrames >= _requiredStableFrames) {
            // Auto-calibrate!
            _gazeTracker.calibrate(face, imageSize, screenSize);
            setState(() {
              _needsCalibration = false;
              _showCalibrationInstructions = false;
            });

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Calibrated! Move your head to control the cursor.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          _faceDetectedFrames = 0;
        }
      }

      GazeData? gazeData;
      if (faces.isNotEmpty && !_needsCalibration) {
        gazeData = _gazeTracker.calculateGaze(
          faces.first,
          imageSize,
          screenSize,
        );
      }

      setState(() {
        _faces = faces;
        _imageSize = imageSize;
        _currentGaze = gazeData;

        if (_needsCalibration && faces.isNotEmpty) {
          final face = faces.first;
          final faceSize = face.boundingBox.width * face.boundingBox.height;
          final imageArea = imageSize.width * imageSize.height;
          final faceRatio = (faceSize / imageArea * 100).toInt();
          _debugInfo = 'Face: $faceRatio% | Frames: $_faceDetectedFrames/$_requiredStableFrames';
        } else {
          _debugInfo = 'Frame: $_frameCount | Faces: ${faces.length}';
        }
      });
    } catch (e) {
      print('✗ Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _recalibrate() {
    setState(() {
      _needsCalibration = true;
      _showCalibrationInstructions = true;
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
            const Duration(milliseconds: 100),
                (_) => _currentGaze?.gazePoint,
          ).where((point) => point != null).cast<Offset>(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eye Control App'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized && !_needsCalibration)
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(gazeTracker: _gazeTracker),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          if (_isInitialized && !_needsCalibration)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _recalibrate,
              tooltip: 'Recalibrate',
            ),
          if (_isInitialized && !_needsCalibration)
            IconButton(
              icon: const Icon(Icons.apps),
              onPressed: _openAppSelector,
              tooltip: 'App Selector',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return _buildErrorWidget(_errorMessage, showSettingsButton: true);
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorWidget(_errorMessage);
    }

    if (!_isInitialized || _cameraController == null || _camera == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Camera preview
        SizedBox(
          width: size.width,
          height: size.height,
          child: CameraPreview(_cameraController!),
        ),

        // Face detection overlay
        if (_imageSize != null)
          CustomPaint(
            size: size,
            painter: FaceDetectorPainter(
              faces: _faces,
              imageSize: _imageSize!,
              rotation: InputImageRotation.rotation270deg,
              cameraLensDirection: _camera!.lensDirection,
            ),
          ),

        // Gaze cursor (only after calibration)
        if (!_needsCalibration && _currentGaze != null)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentGaze?.gazePoint,
              confidence: _currentGaze?.confidence ?? 0.0,
            ),
          ),

        // Calibration instructions overlay
        if (_showCalibrationInstructions)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.center_focus_strong,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Setup Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            '1. Hold phone 20-30 cm from face',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '2. Ensure your whole head is visible',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '3. Hold still for 1 second',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_faces.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _faceDetectedFrames > 0
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _faceDetectedFrames > 0 ? Icons.check_circle : Icons.warning,
                              color: _faceDetectedFrames > 0 ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _faceDetectedFrames > 0
                                  ? 'Good position! Hold still...'
                                  : 'Adjust distance (too close/far)',
                              style: TextStyle(
                                color: _faceDetectedFrames > 0 ? Colors.green : Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _faceDetectedFrames / _requiredStableFrames,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 8,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Looking for face...',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Status bar (after calibration)
        if (!_showCalibrationInstructions)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _faces.isNotEmpty ? Icons.face : Icons.face_outlined,
                    color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _faces.isNotEmpty ? '✓ Tracking' : 'Searching...',
                      style: TextStyle(
                        color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'READY',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorWidget(String message, {bool showSettingsButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (showSettingsButton) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}