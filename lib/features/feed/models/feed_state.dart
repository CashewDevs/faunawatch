import 'package:faunawatch/features/feed/models/feed_post.dart';

/// Presentation state of the For You feed.
class FeedState {
  const FeedState({
    this.posts = const [],
    this.pinnedPost,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.hasError = false,
    this.message,
    this.focusedPostId,
  });

  /// Loaded pages, newest first.
  final List<FeedPost> posts;

  /// A post opened from the map that is not in [posts] yet. It is shown first
  /// and dropped once a refresh loads the pages again.
  final FeedPost? pinnedPost;

  /// The first page is loading and there is nothing to show yet.
  final bool isLoading;
  final bool isRefreshing, isLoadingMore;

  /// There may be older posts to load.
  final bool hasMore;

  /// The first page failed to load and there is nothing to show.
  final bool hasError;

  /// A one-time notice for the user, e.g. a like that could not be saved.
  final String? message;

  /// A post the view should scroll to, once.
  final String? focusedPostId;

  /// What the feed shows, in order.
  List<FeedPost> get visiblePosts {
    final pinned = pinnedPost;
    if (pinned == null || posts.any((post) => post.id == pinned.id)) {
      return posts;
    }
    return [pinned, ...posts];
  }

  FeedState copyWith({
    List<FeedPost>? posts,
    FeedPost? pinnedPost,
    bool clearPinned = false,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    bool? hasError,
    String? message,
    bool clearMessage = false,
    String? focusedPostId,
    bool clearFocus = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      pinnedPost: clearPinned ? null : pinnedPost ?? this.pinnedPost,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      hasError: hasError ?? this.hasError,
      message: clearMessage ? null : message ?? this.message,
      focusedPostId: clearFocus ? null : focusedPostId ?? this.focusedPostId,
    );
  }
}
