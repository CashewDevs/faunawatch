import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/viewmodels/post_comments_viewmodel.dart';
import 'package:faunawatch/features/feed/viewmodels/post_likes_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/animated_heart.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';

/// Author picture and engagement actions floating over a post's photos.
///
/// The rail has no background, so a contrasting glow keeps theme-colored icons
/// readable over both the photo and the screen background.
class PostActionRail extends ConsumerWidget {
  const PostActionRail({super.key, required this.post});
  final FeedPost post;

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
    final isLiked = ref.watch(postLikesViewModelProvider).contains(post.id);
    final commentCount = ref
        .watch(postCommentsViewModelProvider(post.id))
        .totalCount;
    final likeCount = post.likeCount + (isLiked ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: "${post.author}'s profile picture",
          child: PostAvatar(size: 48, asset: post.authorAvatarAsset),
        ),
        const SizedBox(height: 6),
        _RailAction(
          label: 'Like',
          count: likeCount,
          shadows: shadows,
          onTap: () =>
              ref.read(postLikesViewModelProvider.notifier).toggle(post.id),
          child: AnimatedHeart(
            isLiked: isLiked,
            size: 32,
            color: color,
            unlikedIcon: Icons.favorite,
            shadows: shadows,
          ),
        ),
        _RailAction(
          label: 'Comments',
          count: commentCount,
          shadows: shadows,
          onTap: () => PostCommentsSheet.show(context, post),
          child: Icon(Icons.sms, color: color, size: 32, shadows: shadows),
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.label,
    required this.count,
    required this.shadows,
    required this.onTap,
    required this.child,
  });
  final String label;
  final int count;
  final List<Shadow> shadows;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: 2),
              Text(
                formatCompactCount(count),
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
