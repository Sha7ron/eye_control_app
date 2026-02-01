import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../widgets/face_detector_painter.dart';

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
  List<Face> _faces = [];
  bool _isDetecting = false;
  Size? _imageSize;
  int _frameCount = 0;
  String _debugInfo = '';

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

      final frontCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      // Start image stream for face detection
      _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isInitialized = true;
        _debugInfo = 'Camera initialized, waiting for faces...';
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

      setState(() {
        _faces = faces;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _debugInfo = 'Frame: $_frameCount | Faces: ${faces.length} | Image: ${image.width}x${image.height}';
      });

      if (faces.isNotEmpty) {
        print('✓ Face detected! Count: ${faces.length}');
      }
    } catch (e) {
      print('✗ Error detecting faces: $e');
      setState(() {
        _debugInfo = 'Error: $e';
      });
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
        title: const Text('Eye Control App - Phase 2'),
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

    if (!_isInitialized || _cameraController == null) {
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
              widgetSize: size,
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
                  'Faces: ${_faces.length}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _debugInfo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                if (_faces.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '🔵 Blue = Eyes | 🔴 Red = Landmarks',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_faces.isEmpty && _frameCount > 30) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tips:\n• Face the camera directly\n• Ensure good lighting\n• Remove glasses if possible',
                    style: TextStyle(
                      color: Colors.yellowAccent.withOpacity(0.8),
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