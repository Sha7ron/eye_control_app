import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'dart:typed_data';
import '../services/iris_detector_service.dart';
import '../services/gaze_tracker.dart';
import '../utils/camera_image_converter.dart';
import '../widgets/iris_painter.dart';
import '../widgets/gaze_cursor_painter.dart';
import '../models/calibration_point.dart';
import 'calibration_screen.dart';
import 'app_selector_screen.dart';

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
  final IrisDetectorService _irisDetector = IrisDetectorService();
  final GazeTracker _gazeTracker = GazeTracker();
  List<Face> _faces = [];
  bool _isDetecting = false;
  int _frameCount = 0;
  String _debugInfo = '';
  CameraDescription? _camera;

  // Actual processed image size
  Size _processedImageSize = const Size(640, 480);

  // Gaze tracking
  GazeData? _currentGaze;

  // Calibration
  bool _showCalibration = false;
  List<CalibrationPoint> _calibrationPoints = [];

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
      await _irisDetector.initialize();

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
        ResolutionPreset.medium, // Use medium for consistent size
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
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

      // Convert and get actual dimensions
      final conversion = CameraImageConverter.convertCameraImageToJpeg(image);
      final imageBytes = conversion['bytes'] as Uint8List;
      final actualWidth = conversion['width'] as int;
      final actualHeight = conversion['height'] as int;

      // Update processed image size
      _processedImageSize = Size(actualWidth.toDouble(), actualHeight.toDouble());

      // Detect faces
      final faces = await _irisDetector.detectFaces(imageBytes);

      final screenSize = MediaQuery.of(context).size;

      GazeData? gazeData;
      if (faces.isNotEmpty && faces.first.eyes != null) {
        gazeData = _gazeTracker.calculateGaze(
          faces.first,
          _processedImageSize,
          screenSize,
        );
      }

      setState(() {
        _faces = faces;
        _currentGaze = gazeData;
        _debugInfo = 'Frame: $_frameCount | ${actualWidth}x${actualHeight}';
      });
    } catch (e) {
      print('✗ Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _startCalibration() {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _calibrationPoints = _gazeTracker.createCalibrationPoints(screenSize);
      _showCalibration = true;
    });
  }

  void _onPointCalibrated(int index) {
    if (_faces.isNotEmpty) {
      final screenSize = MediaQuery.of(context).size;
      _gazeTracker.addCalibrationData(
        index,
        _faces.first,
        _processedImageSize,
        screenSize,
      );
    }
  }

  void _onCalibrationComplete() {
    setState(() {
      _showCalibration = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Calibration complete! Try the app selector.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openAppSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSelectorScreen(
          onGazeUpdate: (gazePoint) {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _irisDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eye Control'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized && !_showCalibration)
            IconButton(
              icon: Icon(
                _gazeTracker.isCalibrated ? Icons.check_circle : Icons.settings,
                color: _gazeTracker.isCalibrated ? Colors.green : Colors.white,
              ),
              onPressed: _startCalibration,
              tooltip: 'Calibrate',
            ),
          if (_isInitialized && _gazeTracker.isCalibrated && !_showCalibration)
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

    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing...'),
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

        // Face/Iris overlay
        if (!_showCalibration)
          CustomPaint(
            size: size,
            painter: IrisPainter(
              faces: _faces,
              imageSize: _processedImageSize,
              canvasSize: size,
            ),
          ),

        // Gaze cursor
        if (!_showCalibration)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentGaze?.gazePoint,
              confidence: _currentGaze?.confidence ?? 0.0,
            ),
          ),

        // Calibration
        if (_showCalibration)
          CalibrationScreen(
            calibrationPoints: _calibrationPoints,
            onPointCalibrated: _onPointCalibrated,
            onCalibrationComplete: _onCalibrationComplete,
          ),

        // Status
        if (!_showCalibration)
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                          _faces.isNotEmpty && _faces.first.eyes != null
                              ? '✓ Tracking'
                              : 'Searching...',
                          style: TextStyle(
                            color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_gazeTracker.isCalibrated)
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
                  const SizedBox(height: 4),
                  Text(
                    _debugInfo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
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