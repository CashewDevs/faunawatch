import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_post_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/not_public_post_dialog.dart';

/// Full photos and engagement for a single own post, loaded on demand. A
/// pending or declined post shows its status badge (and a declined post its
/// reason), and its like and comment buttons explain why they are closed.
/// Tapping the location closes the viewer and shows the post on the map.
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
      status: item.status,
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
    final focus = MapFocus.fromPost(post, isPublic: state.isPublic);
    final onLocation = focus == null
        ? null
        : () {
            // The map lives in the shell's Feed tab, under this viewer.
            Navigator.of(context).popUntil((route) => route.isFirst);
            ref.read(communityMapViewModelProvider.notifier).focusOn(focus);
          };
    if (!state.isPublic) {
      final reason = state.declineReason;
      return Stack(
        children: [
          Positioned.fill(
            child: FeedPostCard(
              post: post,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              onAuthorTap: onAuthorTap,
              onLike: () => showNotPublicPostDialog(context, state.status),
              onComments: () => showNotPublicPostDialog(context, state.status),
              onLocation: onLocation,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PostStatusBadge(status: state.status, large: true),
                if (state.isDeclined && reason != null) ...[
                  const SizedBox(height: 6),
                  _DeclineReason(label: reason.label),
                ],
              ],
            ),
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
      onLocation: onLocation,
    );
  }
}

class _DeclineReason extends StatelessWidget {
  const _DeclineReason({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Reason: $label',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
