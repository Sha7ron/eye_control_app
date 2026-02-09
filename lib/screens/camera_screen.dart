import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../services/advanced_gaze_tracker.dart';
import '../widgets/gaze_cursor_painter.dart';
import 'precise_calibration_screen.dart';
import 'app_selector_with_gaze.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _permissionDenied = false;
  String _errorMessage = '';

  final FaceDetectorService _faceDetector = FaceDetectorService();
  final AdvancedGazeTracker _gazeTracker = AdvancedGazeTracker();

  List<Face> _faces = [];
  bool _isDetecting = false;
  Size? _imageSize;

  AdvancedGazeData? _currentGaze;
  bool _showCalibration = false;
  List<Offset> _calibrationPoints = [];

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
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high, // Higher resolution for better accuracy
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
      final faces = await _faceDetector.detectFaces(image);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      AdvancedGazeData? gazeData;
      if (faces.isNotEmpty && _gazeTracker.isCalibrated && !_showCalibration) {
        final screenSize = MediaQuery.of(context).size;
        gazeData = _gazeTracker.calculateGaze(faces.first, imageSize, screenSize);
      }

      setState(() {
        _faces = faces;
        _imageSize = imageSize;
        _currentGaze = gazeData;
      });
    } catch (e) {
      print('Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _startCalibration() {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _calibrationPoints = _gazeTracker.getCalibrationPoints(screenSize);
      _showCalibration = true;
    });
  }

  void _onPointCalibrated(int index) {
    if (_faces.isNotEmpty && _imageSize != null) {
      _gazeTracker.addCalibrationSample(
        index,
        _faces.first,
        _calibrationPoints[index],
        _imageSize!,
      );
    }
  }

  void _onCalibrationComplete() {
    setState(() {
      _showCalibration = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Calibration complete! Gaze is now precise.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openAppSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSelectorWithGaze(
          gazeStream: Stream.periodic(
            const Duration(milliseconds: 50),
                (_) => _currentGaze?.screenPoint,
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
        title: const Text('Precise Eye Control'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized)
            IconButton(
              icon: Icon(
                _gazeTracker.isCalibrated ? Icons.check_circle : Icons.settings,
                color: _gazeTracker.isCalibrated ? Colors.green : Colors.white,
              ),
              onPressed: _startCalibration,
            ),
          if (_gazeTracker.isCalibrated)
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
    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
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

        if (_gazeTracker.isCalibrated && !_showCalibration && _currentGaze != null)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentGaze!.screenPoint,
              confidence: _currentGaze!.confidence,
            ),
          ),

        if (_showCalibration)
          PreciseCalibrationScreen(
            calibrationPoints: _calibrationPoints,
            onPointCalibrated: _onPointCalibrated,
            onComplete: _onCalibrationComplete,
          ),
      ],
    );
  }
}