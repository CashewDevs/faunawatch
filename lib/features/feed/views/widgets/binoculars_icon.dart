import 'package:flutter/material.dart';

/// A custom vector painter that draws a clean silhouette of binoculars.
class BinocularsPainter extends CustomPainter {
  const BinocularsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Eyepieces at top
    final leftEyepiece = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.06, w * 0.22, h * 0.14),
      Radius.circular(w * 0.05),
    );
    final rightEyepiece = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.60, h * 0.06, w * 0.22, h * 0.14),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(leftEyepiece, paint);
    canvas.drawRRect(rightEyepiece, paint);

    // Left barrel body
    final leftBarrel = Path()
      ..moveTo(w * 0.20, h * 0.20)
      ..lineTo(w * 0.38, h * 0.20)
      ..lineTo(w * 0.42, h * 0.82)
      ..arcToPoint(
        Offset(w * 0.10, h * 0.82),
        radius: Radius.circular(w * 0.16),
        clockwise: false,
      )
      ..lineTo(w * 0.14, h * 0.45)
      ..close();
    canvas.drawPath(leftBarrel, paint);

    // Right barrel body (mirrored)
    final rightBarrel = Path()
      ..moveTo(w * 0.80, h * 0.20)
      ..lineTo(w * 0.62, h * 0.20)
      ..lineTo(w * 0.58, h * 0.82)
      ..arcToPoint(
        Offset(w * 0.90, h * 0.82),
        radius: Radius.circular(w * 0.16),
        clockwise: true,
      )
      ..lineTo(w * 0.86, h * 0.45)
      ..close();
    canvas.drawPath(rightBarrel, paint);

    // Connecting top bridge
    final topBridge = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.36, h * 0.26, w * 0.28, h * 0.08),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(topBridge, paint);

    // Connecting bottom bridge
    final bottomBridge = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.38, h * 0.56, w * 0.24, h * 0.07),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(bottomBridge, paint);

    // Central focus adjustment knob
    final focusKnob = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.43, h * 0.22, w * 0.14, h * 0.22),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(focusKnob, paint);
  }

  @override
  bool shouldRepaint(covariant BinocularsPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Renders a light gray silhouette of binoculars.
class BinocularsIcon extends StatelessWidget {
  const BinocularsIcon({
    super.key,
    this.size = 88.0,
    this.color = const Color(0xFFCBD5E1),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: BinocularsPainter(color: color),
    );
  }
}
