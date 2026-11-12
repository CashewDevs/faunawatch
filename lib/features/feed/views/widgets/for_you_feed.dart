import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/widgets/inset_centered_scroll.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';

/// The For You tab: approved reports, one full-screen post at a time. Swipe up
/// for older posts (more load as the last ones come near) and pull down to
/// refresh.
class ForYouFeed extends ConsumerStatefulWidget {
  const ForYouFeed({
    super.key,
    required this.backgroundColor,
    required this.isDark,
  });

  final Color backgroundColor;
  final bool isDark;

  @override
  ConsumerState<ForYouFeed> createState() => _ForYouFeedState();
}

class _ForYouFeedState extends ConsumerState<ForYouFeed> {
  /// Start loading older posts when this few posts are left ahead.
  static const _loadMoreThreshold = 3;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 8),
        ),
      );
    ref.read(feedViewModelProvider.notifier).clearMessage();
  }

  /// Scrolls to a post requested by the map, once it is in the list.
  void _focus(String? postId) {
    if (postId == null) return;
    final viewModel = ref.read(feedViewModelProvider.notifier);
    final index = ref
        .read(feedViewModelProvider)
        .visiblePosts
        .indexWhere((post) => post.id == postId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) _controller.jumpToPage(index);
      viewModel.consumeFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedViewModelProvider.select((state) => state.message), (
      _,
      message,
    ) {
      if (message != null) _showMessage(message);
    });
    ref.listen(
      feedViewModelProvider.select((state) => state.focusedPostId),
      (_, postId) => _focus(postId),
    );
    final state = ref.watch(feedViewModelProvider);
    final viewModel = ref.read(feedViewModelProvider.notifier);
    final posts = state.visiblePosts;

    if (posts.isEmpty) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return InsetCenteredScroll(
        onRefresh: viewModel.refresh,
        child: state.hasError
            ? _FeedNotice(
                isDark: widget.isDark,
                title: 'Could not load the feed.',
                body: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: viewModel.refresh,
              )
            : _FeedNotice(
                isDark: widget.isDark,
                title: 'No posts yet.',
                body:
                    'Sightings and wildlife reports in your community will '
                    'appear here.',
              ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: posts.length,
            onPageChanged: (index) {
              if (index >= posts.length - _loadMoreThreshold) {
                viewModel.loadMore();
              }
            },
            itemBuilder: (context, index) => FeedPostCard(
              key: ValueKey(posts[index].id),
              post: posts[index],
              backgroundColor: widget.backgroundColor,
            ),
          ),
        ),
        if (state.isLoadingMore)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class _FeedNotice extends StatelessWidget {
  const _FeedNotice({
    required this.isDark,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final bool isDark;
  final String title, body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Light gray silhouette of binoculars
          BinocularsIcon(
            size: 96,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
