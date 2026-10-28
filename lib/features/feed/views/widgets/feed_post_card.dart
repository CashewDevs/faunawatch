import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({super.key, required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Chip(
          avatar: Icon(Icons.science_outlined, size: 18),
          label: Text('Sample post'),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PostImageCarousel(
              key: ValueKey(post.id),
              imageAssets: post.imageAssets,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          post.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(post.author, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(post.location, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text(post.summary),
        const SizedBox(height: 12),
        Text(post.body),
        const SizedBox(height: 12),
        Text(
          'Demo only - Not a real wildlife report',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
