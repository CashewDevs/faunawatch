import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// A heart that turns red with a quick pop when liked.
class AnimatedHeart extends StatefulWidget {
  const AnimatedHeart({
    super.key,
    required this.isLiked,
    required this.size,
    required this.color,
    this.unlikedIcon = Icons.favorite_border,
    this.shadows,
  });

  final bool isLiked;
  final double size;

  /// Color while not liked.
  final Color color;
  final IconData unlikedIcon;
  final List<Shadow>? shadows;

  @override
  State<AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.4), weight: 40),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        widget.isLiked ? Icons.favorite : widget.unlikedIcon,
        color: widget.isLiked ? AppColors.feedLikeRed : widget.color,
        size: widget.size,
        shadows: widget.shadows,
      ),
    );
  }
}
