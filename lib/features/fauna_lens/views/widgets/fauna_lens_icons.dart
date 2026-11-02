import 'package:flutter/material.dart';

/// Framed landscape picture icon from the FaunaLens design, with a sun and
/// mountains on a [background].
class FaunaLensPictureIcon extends StatelessWidget {
  const FaunaLensPictureIcon({
    super.key,
    required this.size,
    required this.color,
    required this.background,
  });

  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.76),
      painter: _PicturePainter(color: color, background: background),
    );
  }
}

class _PicturePainter extends CustomPainter {
  const _PicturePainter({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final frame = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09;

    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    canvas.drawRect(Offset.zero & size, frame);
    canvas.drawCircle(Offset(w * 0.8, h * 0.24), w * 0.075, fill);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.1, h * 0.86)
        ..lineTo(w * 0.1, h * 0.62)
        ..lineTo(w * 0.28, h * 0.36)
        ..lineTo(w * 0.47, h * 0.66)
        ..lineTo(w * 0.6, h * 0.48)
        ..lineTo(w * 0.9, h * 0.86)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) =>
      color != oldDelegate.color || background != oldDelegate.background;
}

/// Round-headed map pin from the FaunaLens no-location notice.
class FaunaLensPinIcon extends StatelessWidget {
  const FaunaLensPinIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Container(
          width: 2,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// The four rounded corner marks that frame the animal in the viewfinder.
class FaunaLensFrameCorners extends StatelessWidget {
  const FaunaLensFrameCorners({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _FrameCornersPainter());
  }
}

class _FrameCornersPainter extends CustomPainter {
  const _FrameCornersPainter();

  static const double _strokeWidth = 7;
  static const double _armLength = 42;
  static const double _radius = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    // The same corner is drawn four times, mirrored about the frame's center.
    final inset = _strokeWidth / 2;
    final corner = Path()
      ..moveTo(inset, inset + _armLength)
      ..lineTo(inset, inset + _radius)
      ..arcToPoint(
        Offset(inset + _radius, inset),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(inset + _armLength, inset);

    for (final (x, y) in const [
      (1.0, 1.0),
      (-1.0, 1.0),
      (1.0, -1.0),
      (-1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(x < 0 ? size.width : 0, y < 0 ? size.height : 0);
      canvas.scale(x, y);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FrameCornersPainter oldDelegate) => false;
}
