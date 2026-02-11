import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class SmoothCalibrationScreen extends StatefulWidget {
  final Function(int, Offset) onPointCalibrated;
  final VoidCallback onComplete;
  final Size screenSize;
  final bool faceDetected;

  const SmoothCalibrationScreen({
    Key? key,
    required this.onPointCalibrated,
    required this.onComplete,
    required this.screenSize,
    required this.faceDetected,
  }) : super(key: key);

  @override
  State<SmoothCalibrationScreen> createState() => _SmoothCalibrationScreenState();
}

class _SmoothCalibrationScreenState extends State<SmoothCalibrationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _sampleTimer;

  int _currentPoint = 0;
  int _samplesCollected = 0;
  final int _samplesPerPoint = 15;

  late List<Offset> _calibrationPoints;
  Offset _currentTarget = Offset.zero;

  bool _isMoving = true;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    final marginX = 80.0;
    final marginY = 80.0;

    _calibrationPoints = [
      Offset(marginX, marginY),
      Offset(widget.screenSize.width / 2, marginY),
      Offset(widget.screenSize.width - marginX, marginY),
      Offset(widget.screenSize.width - marginX, widget.screenSize.height / 2),
      Offset(widget.screenSize.width - marginX, widget.screenSize.height - marginY),
      Offset(widget.screenSize.width / 2, widget.screenSize.height - marginY),
      Offset(marginX, widget.screenSize.height - marginY),
      Offset(marginX, widget.screenSize.height / 2),
      Offset(widget.screenSize.width / 2, widget.screenSize.height / 2),
    ];

    _currentTarget = _calibrationPoints[0];

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didUpdateWidget(SmoothCalibrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.faceDetected && !_hasStarted) {
      _startCalibration();
    }
  }

  void _startCalibration() {
    if (_hasStarted) return;

    setState(() {
      _hasStarted = true;
    });

    Future.delayed(const Duration(seconds: 1), _moveToNextPoint);
  }

  void _moveToNextPoint() {
    if (_currentPoint >= _calibrationPoints.length) {
      widget.onComplete();
      return;
    }

    setState(() {
      _isMoving = true;
      _currentTarget = _calibrationPoints[_currentPoint];
      _samplesCollected = 0;
    });

    // Animate to target
    _animController.reset();
    _animController.forward().then((_) {
      setState(() {
        _isMoving = false;
      });

      // Start collecting samples
      Future.delayed(const Duration(milliseconds: 300), _collectSamples);
    });
  }

  void _collectSamples() {
    if (!widget.faceDetected) {
      // Wait for face
      Future.delayed(const Duration(milliseconds: 100), _collectSamples);
      return;
    }

    _sampleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!widget.faceDetected) return;

      widget.onPointCalibrated(_currentPoint, _currentTarget);

      setState(() {
        _samplesCollected++;
      });

      if (_samplesCollected >= _samplesPerPoint) {
        timer.cancel();
        _currentPoint++;
        Future.delayed(const Duration(milliseconds: 500), _moveToNextPoint);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _sampleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Stack(
        children: [
          // Instructions
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.faceDetected ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.faceDetected ? Icons.face : Icons.face_outlined,
                    color: Colors.white,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.faceDetected
                        ? (_hasStarted
                        ? 'Follow the moving dot with your eyes\nPoint ${_currentPoint + 1} of ${_calibrationPoints.length}'
                        : 'Starting calibration...')
                        : 'Position your face in view',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isMoving && _hasStarted) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _samplesCollected / _samplesPerPoint,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Animated target dot
          if (_hasStarted)
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final prevTarget = _currentPoint > 0
                    ? _calibrationPoints[_currentPoint - 1]
                    : _currentTarget;

                final animatedTarget = Offset.lerp(
                  prevTarget,
                  _currentTarget,
                  _animController.value,
                )!;

                return Positioned(
                  left: animatedTarget.dx - 30,
                  top: animatedTarget.dy - 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isMoving ? Colors.blue : Colors.green,
                      boxShadow: [
                        BoxShadow(
                          color: (_isMoving ? Colors.blue : Colors.green).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}