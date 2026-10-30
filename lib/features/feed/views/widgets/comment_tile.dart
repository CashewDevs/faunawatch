import 'dart:io';
import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/views/widgets/animated_heart.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';

/// One comment or reply: author, text, age, and its reactions.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.post,
    required this.avatarSize,
    required this.onReply,
    required this.onLike,
    required this.onDislike,
  });

  final PostComment comment;
  final FeedPost post;
  final double avatarSize;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(color: mutedColor);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostAvatar(
          size: avatarSize,
          asset: comment.authorAvatarAsset,
          filePath: comment.authorAvatarFilePath,
          url: comment.authorAvatarUrl,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: comment.authorName,
                  children: [
                    if (comment.isFromCreator)
                      TextSpan(
                        text: ' · Creator',
                        style: mutedStyle?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.feedCreatorTealDark
                              : AppColors.feedCreatorTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: mutedStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (comment.text.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(comment.text, style: theme.textTheme.bodyMedium),
              ],
              if (comment.imagePath != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(comment.imagePath!),
                    height: 140,
                    fit: BoxFit.cover,
                    semanticLabel: 'Comment photo',
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: mutedColor,
                      size: 40,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    formatCommentAge(comment.createdAt, DateTime.now()),
                    style: mutedStyle,
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: onReply,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Reply',
                        style: mutedStyle?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (comment.isLikedByCreator) ...[
                    const SizedBox(width: 14),
                    _CreatorLikedBadge(post: post),
                  ],
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Like comment, ${comment.likeCount}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onLike,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            AnimatedHeart(
                              isLiked: comment.isLiked,
                              size: 20,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatCompactCount(comment.likeCount),
                              style: mutedStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: 'Dislike comment',
                    selected: comment.isDisliked,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onDislike,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          comment.isDisliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          color: comment.isDisliked
                              ? theme.colorScheme.onSurface
                              : mutedColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The creator's picture with a small heart, marking a comment they liked.
class _CreatorLikedBadge extends StatelessWidget {
  const _CreatorLikedBadge({required this.post});
  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Liked by ${post.author}',
      child: SizedBox(
        width: 26,
        height: 22,
        child: Stack(
          children: [
            PostAvatar(size: 20, asset: post.authorAvatarAsset),
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.favorite,
                color: AppColors.feedLikeRed,
                size: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
