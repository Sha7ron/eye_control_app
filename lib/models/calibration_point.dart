class CalibrationPoint {
  final double x;
  final double y;
  final int index;
  bool isCalibrated;

  // Store eye positions when looking at this point
  double? eyeCenterX;
  double? eyeCenterY;

  CalibrationPoint({
    required this.x,
    required this.y,
    required this.index,
    this.isCalibrated = false,
  });

  void calibrate(double eyeX, double eyeY) {
    eyeCenterX = eyeX;
    eyeCenterY = eyeY;
    isCalibrated = true;
  }
}