import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/models/gallery_post.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';

export 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Loads the current user's approved and pending posts independently of the
/// feed. Filters are applied by the server.
///
/// Each filter remembers its loaded posts for the session: the first visit
/// shows the skeleton, and returning to a filter shows its posts at once while
/// its newest page is checked again in the background and merged in.
class GalleryViewModel extends Notifier<GalleryState> {
  late GalleryService _service;
  List<GalleryPost> _posts = [];
  int _generation = 0;
  final _cache = <GalleryFilter, ({List<GalleryPost> posts, bool hasMore})>{};

  @override
  GalleryState build() {
    _service = ref.watch(galleryServiceProvider);
    _posts = [];
    // Never show one account's posts to another.
    _cache.clear();
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() => _loadFirstPage(generation));
    return const GalleryState(isLoading: true);
  }

  List<GalleryItem> _items(List<GalleryPost> posts) => [
    for (final GalleryPost(:post, :status) in posts)
      GalleryItem(
        id: post.id,
        title: post.title,
        location: post.location,
        date: formatGalleryDate(post.createdAt.toLocal()),
        category: post.categoryLabel,
        imageUrl: post.photoUrls.firstOrNull,
        status: status,
      ),
  ];

  Future<void> _loadFirstPage(int generation) async {
    if (generation != _generation) return;
    try {
      final posts = await _service.fetchPage(filter: state.filter);
      if (generation != _generation) return;
      _posts = posts;
      state = state.copyWith(
        items: _items(posts),
        isLoading: false,
        isRefreshing: false,
        hasError: false,
        hasMore: posts.length >= GalleryService.pageSize,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        hasError: state.items.isEmpty,
        message: state.items.isEmpty ? null : 'Could not refresh your gallery.',
      );
    }
  }

  /// Pull to refresh; ignored while a load is already running.
  Future<void> refresh() async {
    if (state.isLoading || state.isRefreshing) return;
    await reload();
  }

  /// Loads the newest page again even if a load is running (its reply is then
  /// ignored), e.g. after the user submitted a post that must appear.
  Future<void> reload() async {
    state = state.copyWith(
      isLoading: state.items.isEmpty,
      isRefreshing: state.items.isNotEmpty,
      isLoadingMore: false,
      hasError: false,
      clearMessage: true,
    );
    await _loadFirstPage(++_generation);
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        _posts.isEmpty) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearMessage: true);
    try {
      final page = await _service.fetchPage(
        filter: state.filter,
        before: _posts.last.post,
      );
      if (generation != _generation) return;
      final known = _posts.map((entry) => entry.post.id).toSet();
      _posts = [
        ..._posts,
        for (final entry in page)
          if (known.add(entry.post.id)) entry,
      ];
      state = state.copyWith(
        items: _items(_posts),
        isLoadingMore: false,
        hasMore: page.length >= GalleryService.pageSize,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        message: 'Could not load older posts.',
      );
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);

  /// Shows All, Pending or Approved posts.
  void setStatus(GalleryStatusFilter status) =>
      _applyFilter(state.filter.copyWith(status: status));

  /// Shows one category, or every category when [category] is `null`.
  void setCategory(ReportCategory? category) => _applyFilter(
    state.filter.copyWith(category: category, clearCategory: category == null),
  );

  void _applyFilter(GalleryFilter filter) {
    if (filter == state.filter) return;
    if (!state.isLoading && !state.hasError) {
      _cache[state.filter] = (posts: _posts, hasMore: state.hasMore);
    }
    final generation = ++_generation;
    final cached = _cache[filter];
    if (cached == null) {
      _posts = [];
      state = GalleryState(filter: filter, isLoading: true);
      _loadFirstPage(generation);
      return;
    }
    _posts = cached.posts;
    state = GalleryState(
      filter: filter,
      items: _items(_posts),
      hasMore: cached.hasMore,
    );
    _checkForChanges(generation);
  }

  /// Fetches the newest page again and merges it into the remembered posts:
  /// new posts appear, and posts approved, declined or deleted meanwhile leave
  /// it. Older pages already loaded are kept. A failure keeps what is shown.
  Future<void> _checkForChanges(int generation) async {
    try {
      final fresh = await _service.fetchPage(filter: state.filter);
      if (generation != _generation) return;
      final isFullPage = fresh.length >= GalleryService.pageSize;
      final freshIds = {for (final entry in fresh) entry.post.id};
      final older = [
        if (isFullPage)
          for (final entry in _posts)
            if (!freshIds.contains(entry.post.id) &&
                _isOlder(entry.post, fresh.last.post))
              entry,
      ];
      _posts = [...fresh, ...older];
      state = state.copyWith(
        items: _items(_posts),
        hasMore: !isFullPage ? false : (older.isEmpty || state.hasMore),
      );
    } catch (_) {
      // The remembered posts stay; pull to refresh can try again.
    }
  }

  /// Newest-first order of the gallery query: submission time, then id.
  static bool _isOlder(FeedPost post, FeedPost than) {
    final byTime = post.createdAt.compareTo(than.createdAt);
    return byTime < 0 || (byTime == 0 && post.id.compareTo(than.id) < 0);
  }
}

/// Riverpod provider exposing [GalleryViewModel] and [GalleryState].
final galleryViewModelProvider =
    NotifierProvider<GalleryViewModel, GalleryState>(GalleryViewModel.new);

/// Compact submission date for the gallery's narrow footer.
String formatGalleryDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
