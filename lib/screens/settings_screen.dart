import 'package:flutter/material.dart';
import '../services/gaze_tracker.dart';

class SettingsScreen extends StatefulWidget {
  final GazeTracker gazeTracker;

  const SettingsScreen({
    Key? key,
    required this.gazeTracker,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _sensitivityX;
  late double _sensitivityY;
  late bool _distanceCompensation;

  @override
  void initState() {
    super.initState();
    _sensitivityX = widget.gazeTracker.sensitivityX;
    _sensitivityY = widget.gazeTracker.sensitivityY;
    _distanceCompensation = widget.gazeTracker.distanceCompensationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Settings'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cursor Sensitivity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Adjust how much the cursor moves relative to head movement',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Horizontal Sensitivity
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.blue),
              const SizedBox(width: 10),
              const Text('Horizontal:', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: _sensitivityX,
                  min: 1.0,
                  max: 6.0,
                  divisions: 50,
                  label: _sensitivityX.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _sensitivityX = value;
                    });
                    widget.gazeTracker.setSensitivity(_sensitivityX, _sensitivityY);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _sensitivityX.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Vertical Sensitivity
          Row(
            children: [
              const Icon(Icons.swap_vert, color: Colors.green),
              const SizedBox(width: 10),
              const Text('Vertical:    ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: _sensitivityY,
                  min: 1.0,
                  max: 6.0,
                  divisions: 50,
                  label: _sensitivityY.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _sensitivityY = value;
                    });
                    widget.gazeTracker.setSensitivity(_sensitivityX, _sensitivityY);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _sensitivityY.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const Divider(height: 40),

          // Distance Compensation
          SwitchListTile(
            title: const Text('Distance Compensation'),
            subtitle: const Text('Adjust sensitivity based on face distance from camera'),
            value: _distanceCompensation,
            onChanged: (value) {
              setState(() {
                _distanceCompensation = value;
              });
              widget.gazeTracker.setDistanceCompensation(value);
            },
          ),

          const Divider(height: 40),

          // Quick presets
          const Text(
            'Quick Presets',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sensitivityX = 2.5;
                      _sensitivityY = 2.5;
                    });
                    widget.gazeTracker.setSensitivity(2.5, 2.5);
                  },
                  child: const Text('Low'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sensitivityX = 3.5;
                      _sensitivityY = 3.5;
                    });
                    widget.gazeTracker.setSensitivity(3.5, 3.5);
                  },
                  child: const Text('Medium'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sensitivityX = 4.5;
                      _sensitivityY = 4.5;
                    });
                    widget.gazeTracker.setSensitivity(4.5, 4.5);
                  },
                  child: const Text('High'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('• Increase sensitivity if cursor moves too slowly'),
                Text('• Decrease sensitivity if cursor is too jumpy'),
                Text('• Test in app selector to fine-tune'),
                Text('• Enable distance compensation for better accuracy'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}