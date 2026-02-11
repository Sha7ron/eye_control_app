import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';
import '../services/head_tracker.dart';
import '../widgets/gaze_cursor_painter.dart';
import 'simple_calibration_screen.dart';
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
  final HeadTracker _headTracker = HeadTracker();

  List<Face> _faces = [];
  bool _isDetecting = false;
  HeadPoint? _currentPosition;

  bool _needsCalibration = true;
  bool _showCalibration = false;
  int _faceDetectedFrames = 0;

  int _frameCount = 0;
  double _sensitivity = 2.5;

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
        ResolutionPreset.medium,
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

      final faces = await _faceDetector.detectFaces(image);
      final screenSize = MediaQuery.of(context).size;

      // Auto-start calibration
      if (_needsCalibration && faces.isNotEmpty) {
        _faceDetectedFrames++;
        if (_faceDetectedFrames >= 10 && !_showCalibration) {
          setState(() {
            _showCalibration = true;
          });
        }
      } else if (_needsCalibration && faces.isEmpty) {
        _faceDetectedFrames = 0;
      }

      // Calculate head position
      HeadPoint? position;
      if (!_needsCalibration && faces.isNotEmpty) {
        position = _headTracker.calculatePosition(faces.first);
      }

      setState(() {
        _faces = faces;
        _currentPosition = position;
      });
    } catch (e) {
      print('Error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _onCalibrationComplete() {
    if (_faces.isNotEmpty) {
      final screenSize = MediaQuery.of(context).size;
      _headTracker.calibrate(_faces.first, screenSize);
      _headTracker.setSensitivity(_sensitivity);

      setState(() {
        _showCalibration = false;
        _needsCalibration = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Head tracking calibrated! Move your head to control cursor.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _recalibrate() {
    setState(() {
      _needsCalibration = true;
      _showCalibration = false;
      _faceDetectedFrames = 0;
      _currentPosition = null;
    });
    _headTracker.reset();
  }

  void _increaseSensitivity() {
    setState(() {
      _sensitivity = (_sensitivity + 0.5).clamp(1.0, 5.0);
    });
    _headTracker.setSensitivity(_sensitivity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sensitivity: ${_sensitivity.toStringAsFixed(1)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _decreaseSensitivity() {
    setState(() {
      _sensitivity = (_sensitivity - 0.5).clamp(1.0, 5.0);
    });
    _headTracker.setSensitivity(_sensitivity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sensitivity: ${_sensitivity.toStringAsFixed(1)}'),
        duration: const Duration(seconds: 1),
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
                (_) => _currentPosition?.position,
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
        title: const Text('Head Tracking Control'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isInitialized && !_needsCalibration) ...[
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _decreaseSensitivity,
              tooltip: 'Decrease sensitivity',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _increaseSensitivity,
              tooltip: 'Increase sensitivity',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _recalibrate,
              tooltip: 'Recalibrate',
            ),
            IconButton(
              icon: const Icon(Icons.apps),
              onPressed: _openAppSelector,
              tooltip: 'Open apps',
            ),
          ],
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

        // Cursor
        if (!_needsCalibration && _currentPosition != null)
          CustomPaint(
            size: size,
            painter: GazeCursorPainter(
              gazePoint: _currentPosition!.position,
              confidence: _currentPosition!.confidence,
            ),
          ),

        // Calibration screen
        if (_showCalibration)
          SimpleCalibrationScreen(
            faceDetected: _faces.isNotEmpty,
            onComplete: _onCalibrationComplete,
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
                              : 'Tracking (Sensitivity: ${_sensitivity.toStringAsFixed(1)})',
                          style: TextStyle(
                            color: _faces.isNotEmpty ? Colors.green : Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Frame: $_frameCount | Mode: HEAD TRACKING',
                    style: const TextStyle(
                      color: Colors.white70,
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
}