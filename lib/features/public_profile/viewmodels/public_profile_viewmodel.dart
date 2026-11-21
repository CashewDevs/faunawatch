import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart'
    show formatGalleryDate;
import 'package:faunawatch/features/public_profile/models/public_profile_state.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicProfileViewModel
    extends AutoDisposeFamilyNotifier<PublicProfileState, String> {
  late PublicProfileService _service;
  int _generation = 0;
  int _postsGeneration = 0;

  @override
  PublicProfileState build(String arg) {
    final viewerId = ref.watch(currentUserIdProvider).valueOrNull;
    _service = ref.watch(publicProfileServiceProvider);
    final generation = ++_generation;
    ++_postsGeneration;
    ref.onDispose(() {
      ++_generation;
      ++_postsGeneration;
    });
    if (viewerId == null) return const PublicProfileState();
    Future.microtask(() => _load(generation));
    return const PublicProfileState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    try {
      final profile = await _service.fetchProfile(arg);
      if (generation != _generation) return;
      state = PublicProfileState(
        profile: profile,
        isLoadingPosts: profile != null,
      );
      if (profile != null) await _loadPosts(++_postsGeneration);
    } catch (_) {
      if (generation == _generation) {
        state = const PublicProfileState(hasError: true);
      }
    }
  }

  /// Reload identity and approved posts, discarding any superseded replies.
  Future<void> refresh() async {
    ++_postsGeneration;
    if (ref.read(currentUserIdProvider).valueOrNull == null) {
      ++_generation;
      state = const PublicProfileState();
      return;
    }
    state = const PublicProfileState(isLoading: true);
    await _load(++_generation);
  }

  Future<void> _loadPosts(int generation) async {
    try {
      final posts = await _service.fetchPosts(arg, category: state.category);
      if (generation != _postsGeneration) return;
      final matching = _matching(posts);
      state = state.copyWith(
        posts: matching,
        isLoadingPosts: false,
        postsHaveError: false,
        hasMore: posts.length >= PublicProfileService.pageSize,
      );
    } catch (_) {
      if (generation == _postsGeneration) {
        state = state.copyWith(isLoadingPosts: false, postsHaveError: true);
      }
    }
  }

  List<FeedPost> _matching(List<FeedPost> posts) => [
    for (final post in posts)
      if (post.authorId == arg &&
          (state.category == null || post.category == state.category))
        post,
  ];

  Future<void> setCategory(ReportCategory? category) async {
    if (state.category == category || state.profile == null) return;
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
      posts: const [],
      isLoadingPosts: true,
      postsHaveError: false,
      isLoadingMore: false,
      hasMore: false,
      clearMessage: true,
    );
    await _loadPosts(++_postsGeneration);
  }

  Future<void> retryPosts() async {
    if (state.isLoadingPosts) return;
    state = state.copyWith(isLoadingPosts: true, postsHaveError: false);
    await _loadPosts(++_postsGeneration);
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingPosts ||
        state.isLoadingMore ||
        state.posts.isEmpty) {
      return;
    }
    final generation = _postsGeneration;
    final before = state.posts.last;
    state = state.copyWith(isLoadingMore: true, clearMessage: true);
    try {
      final posts = await _service.fetchPosts(
        arg,
        before: before,
        category: state.category,
      );
      if (generation != _postsGeneration) return;
      final ids = state.posts.map((post) => post.id).toSet();
      state = state.copyWith(
        posts: [
          ...state.posts,
          for (final post in _matching(posts))
            if (ids.add(post.id)) post,
        ],
        isLoadingMore: false,
        hasMore: posts.length >= PublicProfileService.pageSize,
      );
    } catch (_) {
      if (generation == _postsGeneration) {
        state = state.copyWith(
          isLoadingMore: false,
          message: 'Could not load older posts.',
        );
      }
    }
  }

  List<GalleryItem> get items => [
    for (final post in state.posts)
      GalleryItem(
        id: post.id,
        title: post.title,
        location: post.location,
        date: formatGalleryDate(post.createdAt.toLocal()),
        category: post.categoryLabel,
        imageUrl: post.photoUrls.firstOrNull,
      ),
  ];

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final publicProfileViewModelProvider = NotifierProvider.autoDispose
    .family<PublicProfileViewModel, PublicProfileState, String>(
      PublicProfileViewModel.new,
    );
