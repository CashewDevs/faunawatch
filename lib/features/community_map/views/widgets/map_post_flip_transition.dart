import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the loading face visible until the preview's photo is decoded.
class MapPostFlipTransition extends StatefulWidget {
  const MapPostFlipTransition({
    super.key,
    required this.animation,
    required this.builder,
  });

  final Animation<double> animation;
  final Widget Function(VoidCallback onReady) builder;

  @override
  State<MapPostFlipTransition> createState() => _MapPostFlipTransitionState();
}

class _MapPostFlipTransitionState extends State<MapPostFlipTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _ready = false;

  void _onReady() {
    if (!mounted || _ready) return;
    setState(() => _ready = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final preview = widget.builder(_onReady);
    final loading = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close post preview',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading post preview…'),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, widget.animation]),
      builder: (context, _) {
        final progress = reducedMotion ? (_ready ? 1.0 : 0.0) : _reveal.value;
        final showPreview = progress >= 0.5;
        final angle = showPreview
            ? (1 - progress) * math.pi
            : -progress * math.pi;
        final closing = widget.animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: closing ? widget.animation.value : 1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(
                angle +
                    (closing ? (1 - widget.animation.value) * math.pi / 2 : 0),
              ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Offstage resolves images while hiding the unready face from
                // painting, interaction and accessibility.
                Offstage(offstage: !showPreview, child: preview),
                if (!showPreview) loading,
              ],
            ),
          ),
        );
      },
    );
  }
}
