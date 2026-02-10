import 'package:flutter/material.dart';
import 'dart:async';

class SmartCalibrationScreen extends StatefulWidget {
  final Function(int) onPointCalibrated;
  final VoidCallback onComplete;
  final List<Offset> points;
  final bool faceDetected;

  const SmartCalibrationScreen({
    Key? key,
    required this.onPointCalibrated,
    required this.onComplete,
    required this.points,
    required this.faceDetected,
  }) : super(key: key);

  @override
  State<SmartCalibrationScreen> createState() => _SmartCalibrationScreenState();
}

class _SmartCalibrationScreenState extends State<SmartCalibrationScreen> {
  int _currentPoint = 0;
  int _samples = 0;
  Timer? _timer;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(SmartCalibrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only start if face is detected and we haven't started yet
    if (widget.faceDetected && !_hasStarted) {
      _startCollection();
    }
  }

  void _startCollection() {
    if (_hasStarted) return;

    setState(() {
      _hasStarted = true;
      _samples = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!widget.faceDetected) {
        // Pause if face lost
        return;
      }

      widget.onPointCalibrated(_currentPoint);

      setState(() {
        _samples++;
      });

      if (_samples >= 10) {
        timer.cancel();

        if (_currentPoint < widget.points.length - 1) {
          setState(() {
            _currentPoint++;
            _samples = 0;
            _hasStarted = false;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _startCollection();
            }
          });
        } else {
          widget.onComplete();
        }
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
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        children: [
          // Instructions
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.faceDetected ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.faceDetected ? Icons.face : Icons.face_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.faceDetected
                        ? 'Look at point ${_currentPoint + 1} of ${widget.points.length}'
                        : 'Position your face in view',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.faceDetected && _hasStarted) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _samples / 10,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Points
          ...List.generate(widget.points.length, (index) {
            final point = widget.points[index];
            final isActive = index == _currentPoint;
            final isDone = index < _currentPoint;

            return Positioned(
              left: point.dx - 25,
              top: point.dy - 25,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
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
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white)
                      : Icon(
                    Icons.circle,
                    color: Colors.white,
                    size: isActive ? 16 : 8,
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