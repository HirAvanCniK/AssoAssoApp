import 'package:flutter/material.dart';

// A [CustomPainter] that renders an animated shrinking border for a turn timer.
//
// It draws a colored line tracing a rounded rectangle's perimeter, shrinking
// clockwise from the top-center as the turn progress decreases from 1.0 to 0.0.
class BorderLineTimerPainter extends CustomPainter {
  // The current progress value controlling the border length (1.0 = full, 0.0 = none).
  final double progress;

  // The color of the border line.
  final Color color;

  // The thickness of the border line in pixels.
  final double strokeWidth;

  // Creates a painter with the specified visual parameters.
  BorderLineTimerPainter({
    required this.progress,
    this.color = Colors.deepPurple,
    this.strokeWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    const radius = 8.0;

    final fullPath = Path();
    final startX = rect.left + (rect.width / 2);
    final startY = rect.top;

    // Define the complete path of the rounded rectangle
    fullPath.moveTo(startX, startY);
    fullPath.lineTo(rect.right - radius, startY);
    fullPath.arcToPoint(Offset(rect.right, startY + radius), radius: const Radius.circular(radius));
    fullPath.lineTo(rect.right, rect.bottom - radius);
    fullPath.arcToPoint(Offset(rect.right - radius, rect.bottom), radius: const Radius.circular(radius));
    fullPath.lineTo(rect.left + radius, rect.bottom);
    fullPath.arcToPoint(Offset(rect.left, rect.bottom - radius), radius: const Radius.circular(radius));
    fullPath.lineTo(rect.left, startY + radius);
    fullPath.arcToPoint(Offset(rect.left + radius, startY), radius: const Radius.circular(radius));
    fullPath.lineTo(startX, startY);
    fullPath.close();

    // Extract the portion of the path to draw based on progress
    final metrics = fullPath.computeMetrics().first;
    final totalLength = metrics.length;
    final drawLength = totalLength * progress;
    final extractPath = metrics.extractPath(totalLength - drawLength, totalLength);

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant BorderLineTimerPainter oldDelegate) {
    // Repaint only if progress changes for better performance
    return oldDelegate.progress != progress;
  }
}
