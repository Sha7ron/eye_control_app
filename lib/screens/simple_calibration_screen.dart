import 'package:flutter/material.dart';
import 'dart:async';

class SimpleCalibrationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool faceDetected;

  const SimpleCalibrationScreen({
    Key? key,
    required this.onComplete,
    required this.faceDetected,
  }) : super(key: key);

  @override
  State<SimpleCalibrationScreen> createState() => _SimpleCalibrationScreenState();
}

class _SimpleCalibrationScreenState extends State<SimpleCalibrationScreen> {
  int _countdown = 3;
  Timer? _timer;
  bool _started = false;

  @override
  void didUpdateWidget(SimpleCalibrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.faceDetected && !_started) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    if (_started) return;
    _started = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        widget.onComplete();
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.faceDetected ? Icons.face : Icons.face_outlined,
              color: widget.faceDetected ? Colors.green : Colors.red,
              size: 100,
            ),
            const SizedBox(height: 40),
            Text(
              widget.faceDetected
                  ? (_countdown > 0
                  ? 'Keep your head still\n$_countdown'
                  : 'Calibrated!')
                  : 'Position your face in view',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.faceDetected ? Colors.green : Colors.red,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Look at the CENTER of the screen\nand hold still for 3 seconds',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}