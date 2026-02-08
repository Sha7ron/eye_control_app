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
  int _collectionProgress = 0;
  Timer? _collectionTimer;

  @override
  void initState() {
    super.initState();
    _startCollection();
  }

  void _startCollection() {
    setState(() {
      _isCollecting = true;
      _collectionProgress = 0;
    });

    _collectionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _collectionProgress += 10;
      });

      // Collect sample
      widget.onPointCalibrated(_currentPoint);

      if (_collectionProgress >= 100) {
        timer.cancel();
        _nextPoint();
      }
    });
  }

  void _nextPoint() {
    if (_currentPoint < widget.calibrationPoints.length - 1) {
      setState(() {
        _currentPoint++;
      });
      Future.delayed(const Duration(milliseconds: 500), _startCollection);
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
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // Instructions
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Calibration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Look at point ${_currentPoint + 1} of ${widget.calibrationPoints.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _collectionProgress / 100,
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
              left: point.dx - 30,
              top: point.dy - 30,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isActive
                      ? Colors.red
                      : Colors.white30,
                  border: Border.all(
                    color: Colors.white,
                    width: isActive ? 3 : 1,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 30)
                      : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isActive ? 24 : 18,
                      fontWeight: FontWeight.bold,
                    ),
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