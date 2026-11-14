import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Turns a pin's preview into view without ever mirroring the post's text.
class MapPostFlipTransition extends StatelessWidget {
  const MapPostFlipTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: progress,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY((1 - progress) * math.pi / 2),
            child: child,
          ),
        );
      },
    );
  }
}
