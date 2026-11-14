import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/community_map/viewmodels/map_post_thumbnail_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anonymous details for an approved report, with a link to its full feed post.
class MapPostDialog extends ConsumerWidget {
  const MapPostDialog({
    super.key,
    required this.preview,
    required this.onSeeMore,
    this.onThumbnailReady,
  });
  final MapPostPreview preview;
  final VoidCallback onSeeMore;
  final VoidCallback? onThumbnailReady;

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
                          const SizedBox(height: 8),
                          Text(
                            preview.author,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
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
