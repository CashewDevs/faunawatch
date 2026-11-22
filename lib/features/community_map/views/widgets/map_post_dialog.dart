import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/community_map/viewmodels/map_post_thumbnail_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Details for an approved report, with its poster and a link to its full
/// feed post. The location stays rounded to about 100 m.
class MapPostDialog extends ConsumerWidget {
  const MapPostDialog({
    super.key,
    required this.preview,
    required this.onSeeMore,
    this.onThumbnailReady,
    this.onAuthorTap,
  });
  final MapPostPreview preview;
  final VoidCallback onSeeMore;
  final VoidCallback? onThumbnailReady;

  /// Opens the poster's profile, given their user id.
  final void Function(String authorId)? onAuthorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final thumbnail = ref.watch(mapPostThumbnailViewModelProvider(preview.id));
    void thumbnailReady() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onThumbnailReady?.call();
      });
    }

    // A URL alone is not ready: wait until Image has decoded its first frame.
    if (!thumbnail.isLoading &&
        (thumbnail.hasError || thumbnail.valueOrNull == null)) {
      thumbnailReady();
    }
    void retryThumbnail() => ref
        .read(mapPostThumbnailViewModelProvider(preview.id).notifier)
        .retry();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: thumbnail.when(
                              skipLoadingOnRefresh: false,
                              data: (url) => url == null
                                  ? const _ThumbnailPlaceholder(
                                      message: 'No photo attached',
                                      icon: Icons.image_outlined,
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      semanticLabel: 'Post thumbnail',
                                      frameBuilder:
                                          (context, child, frame, synchronous) {
                                            if (synchronous || frame != null) {
                                              thumbnailReady();
                                              return child;
                                            }
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                      errorBuilder: (context, error, stack) {
                                        thumbnailReady();
                                        return _ThumbnailPlaceholder(
                                          message: 'Photo unavailable',
                                          icon: Icons.broken_image_outlined,
                                          onRetry: retryThumbnail,
                                        );
                                      },
                                    ),
                              error: (error, stack) => _ThumbnailPlaceholder(
                                message: 'Could not load photo',
                                icon: Icons.broken_image_outlined,
                                onRetry: retryThumbnail,
                              ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approved wildlife report',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MapPostAuthor(
                            postId: preview.id,
                            fallbackName: preview.author,
                            onTap: onAuthorTap,
                          ),
                          Text(
                            preview.location,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(preview.body, style: theme.textTheme.bodySmall),
                        ],
                      ),
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

/// The poster's picture and name, loaded with the post from the feed. Until
/// then, or if it fails, [fallbackName] shows without a link.
class MapPostAuthor extends ConsumerWidget {
  const MapPostAuthor({
    super.key,
    required this.postId,
    required this.fallbackName,
    this.onTap,
  });

  final String postId, fallbackName;
  final void Function(String authorId)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final post = ref.watch(mapPostProvider(postId)).valueOrNull;
    final name = post?.authorName ?? fallbackName;
    final authorId = post?.authorId ?? '';
    final canOpen = onTap != null && authorId.isNotEmpty;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PostAvatar(
            size: 28,
            url: post?.authorAvatarUrl,
            asset: post?.authorAvatarAsset,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (!canOpen) return row;
    return Semantics(
      button: true,
      label: "Open $name's profile",
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap!(authorId),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: row,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({
    required this.message,
    required this.icon,
    this.onRetry,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry photo')),
      ],
    ),
  );
}
