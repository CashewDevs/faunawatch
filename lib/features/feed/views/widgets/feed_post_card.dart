import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/double_tap_like.dart';
import 'package:faunawatch/features/feed/views/widgets/post_action_rail.dart';
import 'package:faunawatch/features/feed/views/widgets/post_caption.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/views/screens/post_photo_viewer.dart';
import 'package:faunawatch/features/public_profile/views/public_profile_navigation.dart';

/// A full-bleed post: edge-to-edge photos with an action rail floating over
/// their lower right, and a full-width caption below them. Each photo is
/// shown whole (portrait photos are not cropped). Tapping one opens it full
/// screen, and double-tapping likes the post.
class FeedPostCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // The shell extends its body behind the floating nav bar and reports the
    // bar's height through this padding.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final openAuthor = post.authorId.isEmpty
        ? null
        : onAuthorTap ?? () => openPublicProfile(context, post.authorId);
    final like =
        onLike ??
        () => ref.read(feedViewModelProvider.notifier).toggleLike(post.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: photoTopGap),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DoubleTapLike(
                    isLiked: post.likedByMe,
                    onLike: like,
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
                ),
                // The rail sits over the lower right of the photo, like a
                // short-video feed, so the caption below can use the full
                // width. The top limit keeps it clear of the photo counter.
                Positioned(
                  top: 48,
                  right: 8,
                  bottom: railBottomGap,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PostActionRail(
                        post: post,
                        onLike: like,
                        onComments: onComments,
                        onAuthorTap: openAuthor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset + 12),
          child: PostCaption(
            post: post,
            onAuthorTap: openAuthor,
            onLocationTap: onLocation,
          ),
        ),
      ],
    );
  }

  /// Space between the top bar and the photo.
  static const photoTopGap = 36.0;

  /// Space between the bottom of the photo area and the action rail.
  static const railBottomGap = 16.0;
}
