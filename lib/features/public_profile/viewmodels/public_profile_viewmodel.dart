import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart'
    show formatGalleryDate;
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/public_profile/models/public_profile_state.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicProfileViewModel
    extends AutoDisposeFamilyNotifier<PublicProfileState, String>
    with PublicProfileChat {
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

  @override
  int get loadGeneration => _generation;
}

final publicProfileViewModelProvider = NotifierProvider.autoDispose
    .family<PublicProfileViewModel, PublicProfileState, String>(
      PublicProfileViewModel.new,
    );

/// Whether the signed-in user may start a chat with the account [userId]
/// from its profile or profile preview: signed in, and not their own account.
///
/// Both Message buttons read this one rule, so a later rule (for example
/// "restricted accounts can't message") only needs to be added here.
final canMessageProvider = Provider.autoDispose.family<bool, String>((
  ref,
  userId,
) {
  final viewerId = ref.watch(currentUserIdProvider).valueOrNull;
  return viewerId != null && viewerId != userId;
});

/// The "Message" action shared by the public profile and its preview sheet:
/// opens or creates a private one-to-one chat with the profile's account.
mixin PublicProfileChat
    on AutoDisposeFamilyNotifier<PublicProfileState, String> {
  /// Changes whenever the profile is reloaded or closed, so a chat that
  /// finishes opening afterwards is ignored.
  int get loadGeneration;

  /// Opens or creates a private one-to-one chat thread with this profile user.
  Future<MessageThread?> openPrivateChat() async {
    final profile = state.profile;
    if (profile == null ||
        !ref.read(canMessageProvider(arg)) ||
        state.isOpeningChat) {
      return null;
    }
    final generation = loadGeneration;
    state = state.copyWith(isOpeningChat: true, clearMessage: true);
    try {
      final user = ChatUser(
        id: arg,
        name: profile.username.isNotEmpty
            ? profile.username
            : FeedPost.fallbackAuthorName,
        avatarAsset: profile.presetAvatar,
        avatarUrl: profile.avatarUrl,
      );
      final thread = await ref.read(messagesServiceProvider).openChat(user);
      if (generation != loadGeneration) return null;
      state = state.copyWith(isOpeningChat: false);
      return thread;
    } catch (_) {
      if (generation == loadGeneration) {
        state = state.copyWith(
          isOpeningChat: false,
          message: 'Could not start this chat. Please try again.',
        );
      }
      return null;
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}
