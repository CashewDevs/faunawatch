import 'package:flutter/material.dart';

/// Allows pagination when filtering leaves too few cards to scroll.
class GalleryLoadMore extends StatelessWidget {
  const GalleryLoadMore({
    super.key,
    required this.isLoading,
    required this.onLoad,
  });

  final bool isLoading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) => Center(
    child: isLoading
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        : TextButton(onPressed: onLoad, child: const Text('Load older posts')),
  );
}
