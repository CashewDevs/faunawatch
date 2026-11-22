import 'package:flutter/material.dart';

/// A post's photos full screen: pinch to zoom, swipe between photos, and a
/// close button. Swiping is paused while a photo is zoomed in, so dragging
/// moves around the photo instead.
class PostPhotoViewer extends StatefulWidget {
  const PostPhotoViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  /// Opens the viewer on top of the current screen at [initialIndex].
  static Future<void> show(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) =>
            PostPhotoViewer(imageUrls: imageUrls, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PostPhotoViewer> createState() => _PostPhotoViewerState();
}

class _PostPhotoViewerState extends State<PostPhotoViewer> {
  late final PageController _pages;
  late int _page;
  var _zoomed = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: urls.length,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => _ZoomablePhoto(
              url: urls[index],
              label: 'Photo ${index + 1} of ${urls.length}',
              zoomed: _zoomed,
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(48),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  if (urls.length > 1)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '${_page + 1} / ${urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One photo that can be pinched to zoom; double-tap returns it to normal.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.label,
    required this.zoomed,
    required this.onZoomChanged,
  });

  final String url;
  final String label;

  /// One-finger dragging moves the photo only while zoomed in; otherwise it
  /// swipes to the next photo.
  final bool zoomed;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reset() {
    _transform.value = Matrix4.identity();
    widget.onZoomChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _reset,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 4,
        panEnabled: widget.zoomed,
        onInteractionEnd: (_) =>
            widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            semanticLabel: widget.label,
            frameBuilder: (context, child, frame, loadedSynchronously) =>
                frame == null && !loadedSynchronously
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : child,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
              semanticLabel: 'Photo unavailable',
            ),
          ),
        ),
      ),
    );
  }
}
