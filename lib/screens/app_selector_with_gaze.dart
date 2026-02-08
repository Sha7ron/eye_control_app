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

  final Map<String, GlobalKey<_DwellButtonState>> _dwellButtonKeys = {
    'phone': GlobalKey<_DwellButtonState>(),
    'messages': GlobalKey<_DwellButtonState>(),
    'camera': GlobalKey<_DwellButtonState>(),
    'settings': GlobalKey<_DwellButtonState>(),
  };

  String? _selectedApp;
  StreamSubscription<Offset>? _gazeSubscription;
  String? _currentHoveredButton;

  @override
  void initState() {
    super.initState();
    _startGazeTracking();
  }

  void _startGazeTracking() {
    _gazeSubscription = widget.gazeStream.listen((gazePoint) {
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

    // Update button states
    if (hoveredButton != _currentHoveredButton) {
      // Stop dwell on previously hovered button
      if (_currentHoveredButton != null) {
        _dwellButtonKeys[_currentHoveredButton]?.currentState?.stopDwell();
      }

      // Start dwell on newly hovered button
      if (hoveredButton != null) {
        _dwellButtonKeys[hoveredButton]?.currentState?.startDwell();
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
      body: SafeArea(
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
                child: const Column(
                  children: [
                    Icon(Icons.visibility, color: Colors.white70, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Look at any app for 2 seconds to select it',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
                    Container(
                      key: _buttonKeys['phone'],
                      child: DwellButton(
                        key: _dwellButtonKeys['phone'],
                        containerKey: _buttonKeys['phone']!,
                        label: 'Phone',
                        icon: Icons.phone,
                        color: Colors.green,
                        onSelected: () => _onAppSelected('Phone'),
                      ),
                    ),
                    Container(
                      key: _buttonKeys['messages'],
                      child: DwellButton(
                        key: _dwellButtonKeys['messages'],
                        containerKey: _buttonKeys['messages']!,
                        label: 'Messages',
                        icon: Icons.message,
                        color: Colors.blue,
                        onSelected: () => _onAppSelected('Messages'),
                      ),
                    ),
                    Container(
                      key: _buttonKeys['camera'],
                      child: DwellButton(
                        key: _dwellButtonKeys['camera'],
                        containerKey: _buttonKeys['camera']!,
                        label: 'Camera',
                        icon: Icons.camera_alt,
                        color: Colors.purple,
                        onSelected: () => _onAppSelected('Camera'),
                      ),
                    ),
                    Container(
                      key: _buttonKeys['settings'],
                      child: DwellButton(
                        key: _dwellButtonKeys['settings'],
                        containerKey: _buttonKeys['settings']!,
                        label: 'Settings',
                        icon: Icons.settings,
                        color: Colors.orange,
                        onSelected: () => _onAppSelected('Settings'),
                      ),
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
    );
  }
}