import 'package:flutter/material.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';

/// Placeholder tiles shown while the gallery's first page loads, e.g. after
/// switching from All to Pending. They match [GalleryCard]'s shape and pulse
/// gently, staying still when the device asks for less motion.
class GallerySkeleton extends StatefulWidget {
  const GallerySkeleton({super.key});

  /// Three rows, enough to fill the visible part of the grid.
  static const tileCount = 9;

  @override
  State<GallerySkeleton> createState() => _GallerySkeletonState();
}

class _GallerySkeletonState extends State<GallerySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverSemantics(
        label: 'Loading your posts',
        liveRegion: true,
        sliver: SliverFadeTransition(
          opacity: _pulse,
          sliver: SliverGrid.builder(
            gridDelegate: galleryGridDelegate,
            itemCount: GallerySkeleton.tileCount,
            itemBuilder: (_, _) =>
                const ExcludeSemantics(child: _SkeletonTile()),
          ),
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = scheme.onSurface.withValues(alpha: 0.12);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Same height and colour as the real tile's title/date footer.
          Container(
            height: 32,
            color: AppPaletteColors.of(context).galleryCardDetailsYellow,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: _Bar(color: bar)),
                const SizedBox(width: 8),
                Expanded(child: _Bar(color: bar)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
