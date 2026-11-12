import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/feed/views/widgets/post_image_carousel.dart';

/// A media-first preview of a map pin with the details below it.
///
/// The warning demo's pin is not a report, so it has no "See more in feed"
/// button: pass a null [onSeeMore].
class MapPostDialog extends StatelessWidget {
  const MapPostDialog({
    super.key,
    required this.preview,
    required this.onSeeMore,
  });
  final MapPostPreview preview;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 420,
        height: (MediaQuery.sizeOf(context).height * 0.85).clamp(0, 700),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PostImageCarousel(imageAssets: preview.imageAssets),
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
            ),
            Flexible(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.isDemo
                          ? 'Sample post'
                          : 'Approved wildlife report',
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
                    Text(preview.author, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(preview.location, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(preview.body, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            if (onSeeMore != null)
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
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
