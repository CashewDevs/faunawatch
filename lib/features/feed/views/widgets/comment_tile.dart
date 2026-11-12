import 'package:flutter/material.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';

/// One comment: author, text and age. Comments have no replies, reactions or
/// photos, so none are shown.
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment, this.now});

  final PostComment comment;

  /// The time the age is measured from; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final age = formatPostAge(comment.createdAt, now ?? DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostAvatar(
          size: 40,
          asset: comment.authorAvatarAsset,
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
                  style: mutedStyle?.copyWith(fontWeight: FontWeight.w600),
                  children: [TextSpan(text: ' · $age', style: mutedStyle)],
                ),
              ),
              const SizedBox(height: 2),
              Text(comment.text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
