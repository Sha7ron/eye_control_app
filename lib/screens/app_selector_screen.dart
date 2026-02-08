import 'package:flutter/material.dart';
import '../widgets/dwell_button.dart';

class AppSelectorScreen extends StatefulWidget {
  final Function(Offset gazePoint) onGazeUpdate;

  const AppSelectorScreen({
    Key? key,
    required this.onGazeUpdate,
  }) : super(key: key);

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  final Map<String, GlobalKey> _buttonKeys = {
    'phone': GlobalKey(),
    'messages': GlobalKey(),
    'camera': GlobalKey(),
    'settings': GlobalKey(),
  };

  String? _selectedApp;

  @override
  void initState() {
    super.initState();
    // Start listening for gaze updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGazeTracking();
    });
  }

  void _startGazeTracking() {
    // This will be called every frame with gaze position
    // We'll check which button (if any) is being looked at
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

    // Reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _selectedApp = null;
        });
      }
    });
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
              // Instructions
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

              // Grid of app buttons
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    DwellButton(
                      key: _buttonKeys['phone'],
                      label: 'Phone',
                      icon: Icons.phone,
                      color: Colors.green,
                      onSelected: () => _onAppSelected('Phone'),
                    ),
                    DwellButton(
                      key: _buttonKeys['messages'],
                      label: 'Messages',
                      icon: Icons.message,
                      color: Colors.blue,
                      onSelected: () => _onAppSelected('Messages'),
                    ),
                    DwellButton(
                      key: _buttonKeys['camera'],
                      label: 'Camera',
                      icon: Icons.camera_alt,
                      color: Colors.purple,
                      onSelected: () => _onAppSelected('Camera'),
                    ),
                    DwellButton(
                      key: _buttonKeys['settings'],
                      label: 'Settings',
                      icon: Icons.settings,
                      color: Colors.orange,
                      onSelected: () => _onAppSelected('Settings'),
                    ),
                  ],
                ),
              ),

              // Selected app indicator
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