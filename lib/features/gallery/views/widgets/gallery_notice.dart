import 'package:flutter/material.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_load_more.dart';

class GalleryNotice extends StatelessWidget {
  const GalleryNotice({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
  });

  final GalleryState state;
  final VoidCallback onRetry, onLoadMore;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.photo_library_outlined, size: 56),
      const SizedBox(height: 16),
      Text(
        state.hasError
            ? 'Could not load your gallery.'
            : state.items.isEmpty
            ? 'No posts yet.'
            : state.hasMore
            ? 'No matching posts loaded.'
            : 'No posts in this category.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        state.hasError
            ? 'Check your connection and try again.'
            : state.items.isEmpty
            ? 'Your approved posts will appear here.'
            : state.hasMore
            ? 'Load older posts or choose another filter.'
            : 'Try another filter.',
        textAlign: TextAlign.center,
      ),
      if (state.hasError)
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      if (state.hasMore)
        GalleryLoadMore(isLoading: state.isLoadingMore, onLoad: onLoadMore),
    ],
  );
}
