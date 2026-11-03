import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

/// A media-first preview with swipeable photos and details below them.
class MapPostDialog extends StatelessWidget {
  const MapPostDialog({
    super.key,
    required this.onSeeMore,
    this.post = sampleMapPost,
  });
  final FeedPost post;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 420,
        height: (MediaQuery.sizeOf(context).height * 0.85).clamp(0, 700),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PostImageCarousel(imageAssets: post.imageAssets),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Close post preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.id == sampleMapPost.id
                          ? 'Sample post'
                          : 'Approved wildlife report',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(post.author, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(post.location, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      post.id == sampleMapPost.id
                          ? 'Demo only - Not a real wildlife report'
                          : post.body,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSeeMore,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('See more in feed'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
