import 'package:flutter/material.dart';
import 'dart:async';

class PreciseCalibrationScreen extends StatefulWidget {
  final Function(int index) onPointCalibrated;
  final VoidCallback onComplete;
  final List<Offset> calibrationPoints;

  const PreciseCalibrationScreen({
    Key? key,
    required this.onPointCalibrated,
    required this.onComplete,
    required this.calibrationPoints,
  }) : super(key: key);

  @override
  State<PreciseCalibrationScreen> createState() => _PreciseCalibrationScreenState();
}

class _PreciseCalibrationScreenState extends State<PreciseCalibrationScreen> {
  int _currentPoint = 0;
  bool _isCollecting = false;
  int _samplesCollected = 0;
  static const int _samplesPerPoint = 10;
  Timer? _collectionTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), _startCollection);
  }

  void _startCollection() {
    setState(() {
      _isCollecting = true;
      _samplesCollected = 0;
    });

    _collectionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      widget.onPointCalibrated(_currentPoint);

      setState(() {
        _samplesCollected++;
      });

      if (_samplesCollected >= _samplesPerPoint) {
        timer.cancel();
        _nextPoint();
      }
    });
  }

  void _nextPoint() {
    if (_currentPoint < widget.calibrationPoints.length - 1) {
      setState(() {
        _currentPoint++;
        _isCollecting = false;
      });
      Future.delayed(const Duration(milliseconds: 300), _startCollection);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _collectionTimer?.cancel();
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
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Gaze Calibration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Look at point ${_currentPoint + 1} of ${widget.calibrationPoints.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _samplesCollected / _samplesPerPoint,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
            ),
          ),

          // Calibration points
          ...List.generate(widget.calibrationPoints.length, (index) {
            final point = widget.calibrationPoints[index];
            final isActive = index == _currentPoint;
            final isCompleted = index < _currentPoint;

            return Positioned(
              left: point.dx - 25,
              top: point.dy - 25,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isActive
                      ? Colors.red.withOpacity(0.8 + 0.2 * (_samplesCollected / _samplesPerPoint))
                      : Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white,
                    width: isActive ? 3 : 1,
                  ),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ] : [],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: isActive ? 12 : 8,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}