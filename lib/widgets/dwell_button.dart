import 'package:flutter/material.dart';
import 'dart:async';

class DwellButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final Duration dwellDuration;
  final Color color;

  const DwellButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.dwellDuration = const Duration(milliseconds: 2000),
    this.color = Colors.blue,
  }) : super(key: key);

  @override
  State<DwellButton> createState() => _DwellButtonState();
}

class _DwellButtonState extends State<DwellButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  double _progress = 0.0;
  Timer? _dwellTimer;
  Timer? _progressTimer;
  AnimationController? _successController;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void startDwell() {
    if (_isHovering) return;

    setState(() {
      _isHovering = true;
      _progress = 0.0;
    });

    // Progress animation
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 50),
          (timer) {
        if (!_isHovering) {
          timer.cancel();
          return;
        }

        setState(() {
          _progress += 0.05 / (widget.dwellDuration.inMilliseconds / 1000);
          if (_progress >= 1.0) {
            _progress = 1.0;
          }
        });
      },
    );

    // Complete dwell after duration
    _dwellTimer?.cancel();
    _dwellTimer = Timer(widget.dwellDuration, () {
      if (_isHovering) {
        _onDwellComplete();
      }
    });
  }

  void stopDwell() {
    setState(() {
      _isHovering = false;
      _progress = 0.0;
    });
    _dwellTimer?.cancel();
    _progressTimer?.cancel();
  }

  void _onDwellComplete() {
    _successController?.forward().then((_) {
      widget.onSelected();
      _successController?.reverse();
      stopDwell();
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _progressTimer?.cancel();
    _successController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _successController!,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_successController!.value * 0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.color.withOpacity(0.2),
              border: Border.all(
                color: _isHovering
                    ? widget.color
                    : widget.color.withOpacity(0.5),
                width: _isHovering ? 4 : 2,
              ),
              boxShadow: _isHovering
                  ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ]
                  : [],
            ),
            child: Stack(
              children: [
                // Progress indicator
                if (_isHovering)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.color.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),

                // Button content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 48,
                        color: _isHovering ? widget.color : Colors.white70,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isHovering ? widget.color : Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isHovering) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}