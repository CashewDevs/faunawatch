import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Likes a post when its photo is double-tapped, with a big heart that pops
/// up where the finger was.
///
/// Double-tapping a post that is already liked shows the heart again but
/// keeps the post liked: only the heart button unlikes. Single taps still
/// reach [child] (they wait a moment to make sure no second tap follows).
class DoubleTapLike extends StatefulWidget {
  const DoubleTapLike({
    super.key,
    required this.isLiked,
    required this.onLike,
    required this.child,
  });

  final bool isLiked;

  /// Likes the post (the same action as the heart button).
  final VoidCallback onLike;
  final Widget child;

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  static const _heartSize = 96.0;

  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _heartAt = null);
        }
      });

  // Pops in a little too big, settles, then fades away.
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  late final Animation<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
  ]).animate(_controller);

  Offset _lastDown = Offset.zero;
  Offset? _heartAt;

  void _onDoubleTap() {
    setState(() => _heartAt = _lastDown);
    _controller.forward(from: 0);
    if (!widget.isLiked) widget.onLike();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heartAt = _heartAt;
    return GestureDetector(
      onDoubleTapDown: (details) => _lastDown = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (heartAt != null)
            Positioned(
              key: const ValueKey('double_tap_heart'),
              left: heartAt.dx - _heartSize / 2,
              top: heartAt.dy - _heartSize / 2,
              width: _heartSize,
              height: _heartSize,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: FadeTransition(
                    opacity: _opacity,
                    child: ScaleTransition(
                      scale: _scale,
                      child: const Icon(
                        Icons.favorite,
                        size: _heartSize,
                        color: AppColors.feedLikeRed,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
