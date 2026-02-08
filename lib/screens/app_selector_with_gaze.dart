import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/dwell_button.dart';

class AppSelectorWithGaze extends StatefulWidget {
  final Stream<Offset> gazeStream;

  const AppSelectorWithGaze({
    Key? key,
    required this.gazeStream,
  }) : super(key: key);

  @override
  State<AppSelectorWithGaze> createState() => _AppSelectorWithGazeState();
}

class _AppSelectorWithGazeState extends State<AppSelectorWithGaze> {
  final Map<String, GlobalKey> _buttonKeys = {
    'phone': GlobalKey(),
    'messages': GlobalKey(),
    'camera': GlobalKey(),
    'settings': GlobalKey(),
  };

  String? _selectedApp;
  StreamSubscription<Offset>? _gazeSubscription;
  String? _currentHoveredButton;

  // Add this: Track current gaze position for debugging
  Offset? _currentGazePoint;

  @override
  void initState() {
    super.initState();
    _startGazeTracking();
  }

  void _startGazeTracking() {
    _gazeSubscription = widget.gazeStream.listen((gazePoint) {
      setState(() {
        _currentGazePoint = gazePoint; // Store for debugging
      });
      _checkButtonHover(gazePoint);
    });
  }

  void _checkButtonHover(Offset gazePoint) {
    String? hoveredButton;

    for (final entry in _buttonKeys.entries) {
      if (_isPointInButton(gazePoint, entry.value)) {
        hoveredButton = entry.key;
        break;
      }
    }

    if (hoveredButton != _currentHoveredButton) {
      if (_currentHoveredButton != null) {
        final key = _buttonKeys[_currentHoveredButton];
        final context = key?.currentContext;
        if (context != null) {
          final state = context.findAncestorStateOfType<DwellButtonState>();
          state?.stopDwell();
        }
      }

      if (hoveredButton != null) {
        final key = _buttonKeys[hoveredButton];
        final context = key?.currentContext;
        if (context != null) {
          final state = context.findAncestorStateOfType<DwellButtonState>();
          state?.startDwell();
        }
      }

      _currentHoveredButton = hoveredButton;
    }
  }

  bool _isPointInButton(Offset point, GlobalKey key) {
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;

    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    return point.dx >= position.dx &&
        point.dx <= position.dx + size.width &&
        point.dy >= position.dy &&
        point.dy <= position.dy + size.height;
  }

  void _onAppSelected(String appName) {
    setState(() {
      _selectedApp = appName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Selected: $appName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _selectedApp = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _gazeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Select App with Eyes'),
        backgroundColor: Colors.blue,
      ),
      body: Stack( // Changed to Stack to add gaze cursor overlay
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.visibility, color: Colors.white70, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Look at any app for 2 seconds to select it',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // DEBUG: Show gaze coordinates
                        if (_currentGazePoint != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Gaze: (${_currentGazePoint!.dx.toInt()}, ${_currentGazePoint!.dy.toInt()})',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Hovering: ${_currentHoveredButton ?? "none"}',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      children: [
                        DwellButton(
                          key: _buttonKeys['phone'],
                          containerKey: _buttonKeys['phone']!,
                          label: 'Phone',
                          icon: Icons.phone,
                          color: Colors.green,
                          onSelected: () => _onAppSelected('Phone'),
                        ),
                        DwellButton(
                          key: _buttonKeys['messages'],
                          containerKey: _buttonKeys['messages']!,
                          label: 'Messages',
                          icon: Icons.message,
                          color: Colors.blue,
                          onSelected: () => _onAppSelected('Messages'),
                        ),
                        DwellButton(
                          key: _buttonKeys['camera'],
                          containerKey: _buttonKeys['camera']!,
                          label: 'Camera',
                          icon: Icons.camera_alt,
                          color: Colors.purple,
                          onSelected: () => _onAppSelected('Camera'),
                        ),
                        DwellButton(
                          key: _buttonKeys['settings'],
                          containerKey: _buttonKeys['settings']!,
                          label: 'Settings',
                          icon: Icons.settings,
                          color: Colors.orange,
                          onSelected: () => _onAppSelected('Settings'),
                        ),
                      ],
                    ),
                  ),

                  if (_selectedApp != null)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Opening $_selectedApp...',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // DEBUG: Gaze cursor overlay
          if (_currentGazePoint != null)
            Positioned(
              left: _currentGazePoint!.dx - 20,
              top: _currentGazePoint!.dy - 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.red, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}