import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared photo presentation for a post's map preview and feed card.
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({
    super.key,
    required this.imageAssets,
    this.counterOnRight = false,
    this.fit = BoxFit.contain,
    this.backgroundColor = Colors.black,
  });
  final List<String> imageAssets;

  /// Moves the page counter to the top-right corner. The map preview keeps it
  /// on the left because its close button occupies the right.
  final bool counterOnRight;
  final BoxFit fit;
  final Color backgroundColor;

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant PostImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageAssets, widget.imageAssets)) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imageAssets;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(widget.backgroundColor) ==
        Brightness.dark;
    final indicatorColor = isDarkBackground ? Colors.white : Colors.black;
    return ColoredBox(
      color: widget.backgroundColor,
      child: images.isEmpty
          ? Center(
              child: Icon(
                Icons.image_outlined,
                color: indicatorColor.withValues(alpha: 0.54),
                size: 48,
                semanticLabel: 'No post photos',
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: ValueKey(Object.hashAll(images)),
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: images.length > 1 ? 32 : 0,
                    ),
                    child: Image.asset(
                      images[index],
                      fit: widget.fit,
                      semanticLabel:
                          'Post photo ${index + 1} of ${images.length}',
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  Positioned(
                    top: 12,
                    left: widget.counterOnRight ? null : 12,
                    right: widget.counterOnRight ? 12 : null,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              '${_page + 1} / ${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < images.length; i++)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: indicatorColor.withValues(
                                    alpha: i == _page ? 1 : 0.38,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
