import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_post_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/pending_post_dialog.dart';

/// Full photos and engagement for a single own post, loaded on demand. A
/// pending post shows a "Pending review" badge, and its like and comment
/// buttons explain that it is waiting for an admin.
class GalleryPostPage extends ConsumerWidget {
  const GalleryPostPage({
    super.key,
    required this.item,
    this.authorId,
    this.onAuthorTap,
  });
  final GalleryItem item;
  final String? authorId;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = galleryPostViewModelProvider((
      id: item.id,
      isPending: item.isPending,
      authorId: authorId,
    ));
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
    if (state.isPending) {
      return Stack(
        children: [
          Positioned.fill(
            child: FeedPostCard(
              post: post,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onAuthorTap: onAuthorTap,
              onLike: () => showPendingPostDialog(context),
              onComments: () => showPendingPostDialog(context),
            ),
          ),
          const Positioned(
            top: 12,
            left: 12,
            child: PendingReviewBadge(large: true),
          ),
        ],
      );
    }
    return FeedPostCard(
      post: post,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onAuthorTap: onAuthorTap,
      onLike: viewModel.toggleLike,
      onComments: () => PostCommentsSheet.show(
        context,
        item.id,
        onChanged: viewModel.commentsChanged,
      ),
    );
  }
}
