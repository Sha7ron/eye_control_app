import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../services/gaze_tracker.dart';
import '../widgets/face_detector_painter.dart';
import '../widgets/gaze_cursor_painter.dart';

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
        _errorMessage = 'Camera permission is required for this app to work.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device.';
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

      // Start image stream for face detection
      _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isInitialized = true;
        _debugInfo = 'Camera initialized successfully';
      });

      print('✓ Camera initialized successfully');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
      print('✗ Camera error: $e');
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

      GazeData? gazeData;
      if (faces.isNotEmpty) {
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
        _debugInfo = 'Frame: $_frameCount | Faces: ${faces.length}';
      });
    } catch (e) {
      print('✗ Error detecting faces: $e');
    } finally {
      _isDetecting = false;
    }
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
        title: const Text('Eye Control App - Phase 3'),
        backgroundColor: Colors.blue,
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

        // Gaze cursor overlay
        CustomPaint(
          size: size,
          painter: GazeCursorPainter(
            gazePoint: _currentGaze?.gazePoint,
            confidence: _currentGaze?.confidence ?? 0.0,
          ),
        ),

        // Status overlay
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _faces.isNotEmpty ? Icons.face : Icons.face_outlined,
                      color: _faces.isNotEmpty ? Colors.greenAccent : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _faces.isNotEmpty
                          ? '✓ Face Detected'
                          : 'Looking for faces...',
                      style: TextStyle(
                        color: _faces.isNotEmpty
                            ? Colors.greenAccent
                            : Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _debugInfo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (_currentGaze != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '👁️ Gaze: (${_currentGaze!.gazePoint.dx.toInt()}, ${_currentGaze!.gazePoint.dy.toInt()})',
                    style: TextStyle(
                      color: Colors.purpleAccent.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (_faces.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🔵 Blue = Eyes | 🔴 Red = Landmarks | 🟣 Purple = Gaze',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
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

  Widget _buildErrorWidget(String message, {bool showSettingsButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (showSettingsButton) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}