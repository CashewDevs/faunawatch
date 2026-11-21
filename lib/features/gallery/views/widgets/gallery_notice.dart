import 'package:flutter/material.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Shown instead of the grid when loading failed or the filter has no posts.
class GalleryNotice extends StatelessWidget {
  const GalleryNotice({super.key, required this.state, required this.onRetry});

  final GalleryState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final empty = state.emptyMessage;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.photo_library_outlined, size: 56),
        const SizedBox(height: 16),
        Text(
          state.hasError ? 'Could not load your gallery.' : empty.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          state.hasError ? 'Check your connection and try again.' : empty.hint,
          textAlign: TextAlign.center,
        ),
        if (state.hasError)
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
