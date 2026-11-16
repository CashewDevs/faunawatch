import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_post_viewmodel.dart';

/// Full photos and engagement for a single own post, loaded on demand.
class GalleryPostPage extends ConsumerWidget {
  const GalleryPostPage({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = galleryPostViewModelProvider(postId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    ref.listen(provider.select((state) => state.message), (_, message) {
      if (message == null) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      viewModel.clearMessage();
    });
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final post = state.post;
    if (post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.hasError
                  ? 'Could not load this post.'
                  : 'This post is no longer available.',
            ),
            TextButton(
              onPressed: viewModel.retry,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    return FeedPostCard(
      post: post,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onLike: viewModel.toggleLike,
      onComments: () => PostCommentsSheet.show(
        context,
        postId,
        onChanged: viewModel.commentsChanged,
      ),
    );
  }
}
