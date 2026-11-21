import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circle that draws itself, then a tick inside it. Shown when a post has
/// been submitted. Appears finished straight away when the device asks for
/// less motion.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.color,
    this.size = 112,
    this.duration = const Duration(milliseconds: 900),
  });

  final Color color;
  final double size;
  final Duration duration;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Submitted',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _CheckPainter(
              progress: Curves.easeInOut.transform(_controller.value),
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  /// 0 to 1: the first 55% draws the circle, the rest draws the tick.
  final double progress;
  final Color color;

  static const _circleShare = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = (Offset.zero & size).deflate(stroke / 2);

    final circle = (progress / _circleShare).clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * circle, false, paint);

    final tick = ((progress - _circleShare) / (1 - _circleShare)).clamp(
      0.0,
      1.0,
    );
    if (tick == 0) return;
    final w = size.width;
    final points = [
      Offset(w * 0.28, w * 0.52),
      Offset(w * 0.44, w * 0.67),
      Offset(w * 0.73, w * 0.37),
    ];
    final first = (points[1] - points[0]).distance;
    final second = (points[2] - points[1]).distance;
    final drawn = (first + second) * tick;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    if (drawn <= first) {
      final end = Offset.lerp(points[0], points[1], drawn / first)!;
      path.lineTo(end.dx, end.dy);
    } else {
      final end = Offset.lerp(points[1], points[2], (drawn - first) / second)!;
      path
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(end.dx, end.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
