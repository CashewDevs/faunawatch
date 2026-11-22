import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/animated_heart.dart';
import 'package:faunawatch/features/feed/views/widgets/post_ai_analysis_sheet.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/public_profile/views/widgets/profile_link.dart';

/// Author picture, engagement actions and (when the post has one) the AI
/// analysis button, floating over a post's photos.
///
/// The rail has no background, so a contrasting glow keeps theme-colored icons
/// readable over both the photo and the screen background.
class PostActionRail extends ConsumerWidget {
  const PostActionRail({
    super.key,
    required this.post,
    this.onLike,
    this.onComments,
    this.onAuthorTap,
  });
  final FeedPost post;
  final VoidCallback? onLike, onComments, onAuthorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    final glow = theme.brightness == Brightness.dark
        ? Colors.black87
        : Colors.white;
    final shadows = [
      Shadow(color: glow, blurRadius: 2),
      Shadow(color: glow, blurRadius: 8),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileLink(
          name: post.authorName,
          onTap: onAuthorTap,
          child: Semantics(
            image: true,
            label: "${post.authorName}'s profile picture",
            child: PostAvatar(
              size: 48,
              asset: post.authorAvatarAsset,
              url: post.authorAvatarUrl,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _RailAction(
          label: '${post.likedByMe ? 'Unlike' : 'Like'}, ${post.likeCount}',
          caption: formatCompactCount(post.likeCount),
          shadows: shadows,
          onTap:
              onLike ??
              () =>
                  ref.read(feedViewModelProvider.notifier).toggleLike(post.id),
          child: AnimatedHeart(
            isLiked: post.likedByMe,
            size: 32,
            color: color,
            unlikedIcon: Icons.favorite,
            shadows: shadows,
          ),
        ),
        _RailAction(
          label: 'Comments, ${post.commentCount}',
          caption: formatCompactCount(post.commentCount),
          shadows: shadows,
          onTap: onComments ?? () => PostCommentsSheet.show(context, post.id),
          child: Icon(Icons.sms, color: color, size: 32, shadows: shadows),
        ),
        if (post.aiAnalysis != null)
          _RailAction(
            label: 'AI analysis',
            caption: 'AI',
            shadows: shadows,
            onTap: () => PostAiAnalysisSheet.show(context, post.aiAnalysis!),
            child: Icon(
              Icons.auto_awesome,
              color: color,
              size: 32,
              shadows: shadows,
            ),
          ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.label,
    required this.caption,
    required this.shadows,
    required this.onTap,
    required this.child,
  });

  /// What screen readers announce, e.g. "Comments, 3".
  final String label;

  /// The short text under the icon, e.g. a count.
  final String caption;
  final List<Shadow> shadows;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 32 dp icons + 8 dp each side: the recommended 48 dp touch width.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: 2),
              Text(
                caption,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  shadows: shadows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
