import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared photo presentation for a post's map preview and feed card.
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({super.key, required this.imageAssets});
  final List<String> imageAssets;

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
    return ColoredBox(
      color: Colors.black,
      child: images.isEmpty
          ? const Center(
              child: Icon(
                Icons.image_outlined,
                color: Colors.white54,
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
                      fit: BoxFit.contain,
                      semanticLabel:
                          'Post photo ${index + 1} of ${images.length}',
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  Positioned(
                    top: 12,
                    left: 12,
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
                                width: i == _page ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _page
                                      ? Colors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(8),
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
