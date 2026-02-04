import 'package:flutter/material.dart';
import 'dart:async';
import '../models/calibration_point.dart';

class CalibrationScreen extends StatefulWidget {
  final List<CalibrationPoint> calibrationPoints;
  final Function(int index) onPointCalibrated;
  final Function() onCalibrationComplete;

  const CalibrationScreen({
    Key? key,
    required this.calibrationPoints,
    required this.onPointCalibrated,
    required this.onCalibrationComplete,
  }) : super(key: key);

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _currentPointIndex = 0;
  int _countdown = 3;
  Timer? _timer;
  bool _isCollecting = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 3;
      _isCollecting = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown == 0) {
        timer.cancel();
        _collectCalibrationData();
      }
    });
  }

  void _collectCalibrationData() {
    setState(() {
      _isCollecting = true;
    });

    // Collect for 2 seconds
    Timer(const Duration(milliseconds: 2000), () {
      widget.onPointCalibrated(_currentPointIndex);

      setState(() {
        _isCollecting = false;
      });

      // Move to next point or finish
      if (_currentPointIndex < widget.calibrationPoints.length - 1) {
        setState(() {
          _currentPointIndex++;
        });
        _startCountdown();
      } else {
        widget.onCalibrationComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPoint = widget.calibrationPoints[_currentPointIndex];

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Stack(
        children: [
          // Instructions
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    '👁️ Eye Calibration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isCollecting
                        ? 'Keep looking at the GREEN circle!'
                        : 'Look at the RED circle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Point ${_currentPointIndex + 1} of ${widget.calibrationPoints.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Calibration point
          Positioned(
            left: currentPoint.x - 40,
            top: currentPoint.y - 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCollecting
                    ? Colors.green.withOpacity(0.7)
                    : Colors.red.withOpacity(0.7),
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isCollecting ? Colors.green : Colors.red)
                        .withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _isCollecting ? '👁️' : '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}