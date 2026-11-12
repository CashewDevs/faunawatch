import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/feed_state.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';

/// Loads the For You feed: the first page, older pages on demand, pull to
/// refresh, likes and the comment counts.
class FeedViewModel extends Notifier<FeedState> {
  late FeedService _service;

  // Bumped whenever the state is rebuilt or disposed (e.g. the account
  // changed), so answers to older requests are ignored.
  int _generation = 0;
  final _likesInFlight = <String>{};

  @override
  FeedState build() {
    _service = ref.watch(feedServiceProvider);
    final generation = ++_generation;
    _likesInFlight.clear();
    ref.onDispose(() => _generation++);
    Future.microtask(() => _loadFirstPage(generation));
    return const FeedState(isLoading: true);
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<void> _loadFirstPage(int generation, {bool dropPinned = false}) async {
    try {
      final page = await _service.fetchPage();
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        posts: page,
        // After a refresh, a post pinned from the map is stale.
        clearPinned: dropPinned,
        isLoading: false,
        isRefreshing: false,
        hasMore: page.length >= FeedService.pageSize,
        hasError: false,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      final hasPosts = state.visiblePosts.isNotEmpty;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasError: !hasPosts,
        message: hasPosts ? 'Could not refresh the feed.' : null,
      );
    }
  }

  /// Loads the first page again; a failure keeps what is already shown.
  Future<void> refresh() async {
    if (state.isLoading || state.isRefreshing) return;
    final hadPosts = state.visiblePosts.isNotEmpty;
    state = state.copyWith(
      isLoading: !hadPosts,
      isRefreshing: hadPosts,
      hasError: false,
      isLoadingMore: false,
    );
    await _loadFirstPage(_generation, dropPinned: true);
  }

  /// Loads the next, older page. Called when the user nears the last post.
  Future<void> loadMore() async {
    final last = state.posts.lastOrNull;
    if (last == null ||
        !state.hasMore ||
        state.isLoading ||
        state.isRefreshing ||
        state.isLoadingMore) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _service.fetchPage(before: last);
      if (!_isCurrent(generation)) return;
      final known = {for (final post in state.posts) post.id};
      state = state.copyWith(
        posts: [
          ...state.posts,
          for (final post in page)
            if (!known.contains(post.id)) post,
        ],
        isLoadingMore: false,
        hasMore: page.length >= FeedService.pageSize,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        isLoadingMore: false,
        message: 'Could not load more posts.',
      );
    }
  }

  /// Likes or unlikes right away and undoes it if saving fails. Taps while the
  /// previous change of the same post is still being saved are ignored.
  Future<void> toggleLike(String postId) async {
    final before = _find(postId);
    if (before == null || _likesInFlight.contains(postId)) return;
    final liked = !before.likedByMe;
    _update(
      postId,
      (post) => post.copyWith(
        likedByMe: liked,
        likeCount: math.max(0, before.likeCount + (liked ? 1 : -1)),
      ),
    );
    _likesInFlight.add(postId);
    final generation = _generation;
    try {
      await (liked ? _service.like(postId) : _service.unlike(postId));
    } catch (_) {
      if (_isCurrent(generation)) {
        _update(
          postId,
          (post) => post.copyWith(
            likedByMe: before.likedByMe,
            likeCount: before.likeCount,
          ),
        );
        state = state.copyWith(message: 'Could not update your like.');
      }
    } finally {
      if (_isCurrent(generation)) _likesInFlight.remove(postId);
    }
  }

  /// Keeps the rail's count in step with the comments sheet.
  void setCommentCount(String postId, int count) {
    _update(postId, (post) => post.copyWith(commentCount: count));
  }

  void adjustCommentCount(String postId, int delta) {
    _update(
      postId,
      (post) =>
          post.copyWith(commentCount: math.max(0, post.commentCount + delta)),
    );
  }

  /// Shows a report in the For You tab, e.g. from the community map. A report
  /// that is not loaded yet is fetched and shown first.
  Future<void> openReport(String postId) async {
    ref.read(feedTabViewModelProvider.notifier).select(FeedTab.forYou);
    if (_find(postId) != null) {
      state = state.copyWith(focusedPostId: postId);
      return;
    }
    final generation = _generation;
    try {
      final post = await _service.fetchPost(postId);
      if (!_isCurrent(generation)) return;
      if (post == null) {
        state = state.copyWith(message: 'That post is no longer available.');
        return;
      }
      state = state.copyWith(pinnedPost: post, focusedPostId: post.id);
    } catch (_) {
      if (_isCurrent(generation)) {
        state = state.copyWith(message: 'Could not open that post.');
      }
    }
  }

  void consumeFocus() => state = state.copyWith(clearFocus: true);

  void clearMessage() => state = state.copyWith(clearMessage: true);

  FeedPost? _find(String postId) {
    final pinned = state.pinnedPost;
    if (pinned != null && pinned.id == postId) return pinned;
    return state.posts.where((post) => post.id == postId).firstOrNull;
  }

  void _update(String postId, FeedPost Function(FeedPost) change) {
    final pinned = state.pinnedPost;
    state = state.copyWith(
      posts: [
        for (final post in state.posts) post.id == postId ? change(post) : post,
      ],
      pinnedPost: pinned != null && pinned.id == postId ? change(pinned) : null,
    );
  }
}

final feedViewModelProvider = NotifierProvider<FeedViewModel, FeedState>(
  FeedViewModel.new,
);

enum FeedTab { gallery, map, forYou }

/// Holds the tab selected at the top of the feed.
class FeedTabViewModel extends Notifier<FeedTab> {
  @override
  FeedTab build() => FeedTab.forYou;

  void select(FeedTab tab) => state = tab;
}

final feedTabViewModelProvider = NotifierProvider<FeedTabViewModel, FeedTab>(
  FeedTabViewModel.new,
);
