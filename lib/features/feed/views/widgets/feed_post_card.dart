import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/views/widgets/post_action_rail.dart';
import 'package:faunawatch/features/feed/views/widgets/post_caption.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/views/screens/post_photo_viewer.dart';
import 'package:faunawatch/features/public_profile/views/public_profile_navigation.dart';

/// A full-bleed post: edge-to-edge photos, a caption below them, and an action
/// rail floating over the right edge. Each photo is shown whole (portrait
/// photos are not cropped), and tapping one opens it full screen.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.backgroundColor,
    this.onLike,
    this.onComments,
    this.onAuthorTap,
    this.onLocation,
  });
  final FeedPost post;
  final Color backgroundColor;
  final VoidCallback? onLike, onComments, onAuthorTap;

  /// Shows the post on the map; null leaves its location as plain text.
  final VoidCallback? onLocation;

  @override
  Widget build(BuildContext context) {
    // The shell extends its body behind the floating nav bar and reports the
    // bar's height through this padding.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final openAuthor = post.authorId.isEmpty
        ? null
        : onAuthorTap ?? () => openPublicProfile(context, post.authorId);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PostImageCarousel.network(
                key: ValueKey(post.id),
                imageUrls: post.photoUrls,
                counterOnRight: true,
                fit: BoxFit.contain,
                backgroundColor: backgroundColor,
                onOpen: (index) => PostPhotoViewer.show(
                  context,
                  post.photoUrls,
                  initialIndex: index,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 80, bottomInset + 12),
              child: PostCaption(
                post: post,
                onAuthorTap: openAuthor,
                onLocationTap: onLocation,
              ),
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
              child: PostActionRail(
                post: post,
                onLike: onLike,
                onComments: onComments,
                onAuthorTap: openAuthor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
