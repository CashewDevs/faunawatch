import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/views/widgets/post_action_rail.dart';
import 'package:faunawatch/features/feed/views/widgets/post_caption.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

/// A full-bleed post: edge-to-edge photos, a caption below them, and an action
/// rail floating over the right edge.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.backgroundColor,
  });
  final FeedPost post;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // The shell extends its body behind the floating nav bar and reports the
    // bar's height through this padding.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PostImageCarousel(
                key: ValueKey(post.id),
                imageAssets: post.imageAssets,
                counterOnRight: true,
                fit: BoxFit.fitWidth,
                backgroundColor: backgroundColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 80, bottomInset + 12),
              child: PostCaption(post: post),
            ),
          ],
        ),
        Positioned(
          top: 48,
          right: 8,
          bottom: bottomInset + 12,
          child: Align(
            alignment: Alignment.bottomRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PostActionRail(post: post),
            ),
          ),
        ),
      ],
    );
  }
}
