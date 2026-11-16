import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';

export 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Loads and filters the current user's own posts independently of the feed.
class GalleryViewModel extends Notifier<GalleryState> {
  late GalleryService _service;
  List<FeedPost> _posts = [];
  int _generation = 0;

  @override
  GalleryState build() {
    _service = ref.watch(galleryServiceProvider);
    _posts = [];
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() => _loadFirstPage(generation));
    return const GalleryState(isLoading: true);
  }

  List<GalleryItem> _items(List<FeedPost> posts) => [
    for (final post in posts)
      GalleryItem(
        id: post.id,
        title: post.title,
        location: post.location,
        date: formatGalleryDate(post.createdAt.toLocal()),
        category: post.categoryLabel,
        imageUrl: post.photoUrls.firstOrNull,
      ),
  ];

  Future<void> _loadFirstPage(int generation) async {
    if (generation != _generation) return;
    try {
      final posts = await _service.fetchPage();
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

  Future<void> refresh() async {
    if (state.isLoading || state.isRefreshing) return;
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
      final page = await _service.fetchPage(before: _posts.last);
      if (generation != _generation) return;
      final known = _posts.map((post) => post.id).toSet();
      _posts = [
        ..._posts,
        for (final post in page)
          if (known.add(post.id)) post,
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

  /// Sets the active category filter for the gallery photos.
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
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
