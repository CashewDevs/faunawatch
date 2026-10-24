import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Interactive indicator displaying the animated upward arrow, slide-up button,
/// and "Slide Up" label.
class SwipeUpIndicator extends StatefulWidget {
  const SwipeUpIndicator({
    super.key,
    required this.onSlideUp,
    this.animate = true,
  });

  final VoidCallback onSlideUp;
  final bool animate;

  @override
  State<SwipeUpIndicator> createState() => _SwipeUpIndicatorState();
}

class _SwipeUpIndicatorState extends State<SwipeUpIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SwipeUpIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
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
      container: true,
      button: true,
      label: 'Slide Up',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onSlideUp,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated upward arrow indicator
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                // Translates upward smoothly from 4 to -8
                final dy = 4.0 - (12.0 * t);
                // Pulses opacity with a smooth fade in and fade out
                final opacity = (math.sin(t * math.pi)).clamp(0.15, 1.0);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Opacity(opacity: opacity, child: child),
                );
              },
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.introSlideUpText,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            // Slide Up Button
            Image.asset(
              AppAssets.slideUpButton,
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            // "Slide Up" Label
            Text(
              'Slide Up',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppColors.introSlideUpText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
