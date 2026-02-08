import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../services/gaze_tracker.dart';
import '../widgets/face_detector_painter.dart';
import '../widgets/gaze_cursor_painter.dart';
import '../models/calibration_point.dart';
import 'calibration_screen.dart';
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
    if (_faces.isNotEmpty && _imageSize != null) {
      final screenSize = MediaQuery.of(context).size;
      _gazeTracker.addCalibrationData(
        index,
        _faces.first,
        _imageSize!,
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
        content: Text('✓ Calibration complete! Tap Apps to try selection.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
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

    if (!_isInitialized || _cameraController == null || _camera == null) {
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
        SizedBox(
          width: size.width,
          height: size.height,
          child: CameraPreview(_cameraController!),
        ),

        if (_imageSize != null && !_showCalibration)
          CustomPaint(
            size: size,
            painter: FaceDetectorPainter(
              faces: _faces,
              imageSize: _imageSize!,
              rotation: InputImageRotation.rotation270deg,
              cameraLensDirection: _camera!.lensDirection,
            ),
          ),

        if (!_showCalibration)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentGaze?.gazePoint,
              confidence: _currentGaze?.confidence ?? 0.0,
            ),
          ),

        if (_showCalibration)
          CalibrationScreen(
            calibrationPoints: _calibrationPoints,
            onPointCalibrated: _onPointCalibrated,
            onCalibrationComplete: _onCalibrationComplete,
          ),

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
                          _faces.isNotEmpty ? '✓ Tracking' : 'Searching...',
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