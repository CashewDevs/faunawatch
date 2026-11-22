import 'package:faunawatch/features/community_map/models/map_pin_spot.dart';
import 'package:faunawatch/features/community_map/viewmodels/map_post_thumbnail_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lists the posts that share one map pin, newest first. Each row shows the
/// post's photo, category, poster and the start of its description; tapping a
/// row calls [onPick] with that post's id.
class MapSpotSheet extends StatelessWidget {
  const MapSpotSheet({super.key, required this.spot, required this.onPick});

  final MapPinSpot spot;
  final void Function(String postId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            '${spot.count} posts here',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Locations are rounded to about 1 km, so nearby posts share a pin.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: spot.count,
            itemBuilder: (context, index) {
              final report = spot.reports[index];
              return _SpotPostTile(
                key: ValueKey(report.id),
                postId: report.id,
                title: report.preview.title,
                description: report.description,
                onTap: () => onPick(report.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpotPostTile extends ConsumerWidget {
  const _SpotPostTile({
    super.key,
    required this.postId,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String postId, title, description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final post = ref.watch(mapPostProvider(postId));
    final author = post.valueOrNull?.authorName;
    return ListTile(
      onTap: onTap,
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _SpotPhoto(
        url: post.valueOrNull?.photoUrls.firstOrNull,
        isLoading: post.isLoading,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        author == null ? description : '$author · $description',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _SpotPhoto extends StatelessWidget {
  const _SpotPhoto({required this.url, required this.isLoading});

  static const _size = 56.0;
  final String? url;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.image_outlined, color: colors.onSurfaceVariant),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: _size,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                // Decode at the size shown, not the full upload.
                cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
