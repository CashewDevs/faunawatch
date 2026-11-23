import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/models/posts_privacy_state.dart';
import 'package:faunawatch/features/profile/services/posts_privacy_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads the signed-in user's "Private posts" setting when Settings opens and
/// saves changes to their account, so it follows them to other phones.
class PostsPrivacyViewModel extends AutoDisposeNotifier<PostsPrivacyState> {
  late PostsPrivacyService _service;
  int _generation = 0;

  static const saveFailedMessage =
      'Could not save Private posts. Check your connection and try again.';

  @override
  PostsPrivacyState build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    _service = ref.watch(postsPrivacyServiceProvider);
    final generation = ++_generation;
    ref.onDispose(() => ++_generation);
    if (userId == null) return const PostsPrivacyState();
    Future.microtask(() => _load(generation));
    return const PostsPrivacyState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    try {
      final isPrivate = await _service.load();
      if (generation == _generation) {
        state = PostsPrivacyState(isPrivate: isPrivate);
      }
    } catch (_) {
      if (generation == _generation) {
        state = const PostsPrivacyState(loadFailed: true);
      }
    }
  }

  /// Reads the setting again after it failed to load.
  Future<void> retry() async {
    if (state.isLoading || state.isSaving) return;
    state = const PostsPrivacyState(isLoading: true);
    await _load(++_generation);
  }

  /// Turns Private posts on or off. The switch moves at once; if saving
  /// fails it moves back and [PostsPrivacyState.message] says why.
  Future<void> setPrivate(bool isPrivate) async {
    if (!state.canChange || state.isPrivate == isPrivate) return;
    final generation = _generation;
    state = state.copyWith(
      isPrivate: isPrivate,
      isSaving: true,
      clearMessage: true,
    );
    try {
      final saved = await _service.save(isPrivate);
      if (generation == _generation) {
        state = state.copyWith(isPrivate: saved, isSaving: false);
      }
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isPrivate: !isPrivate,
          isSaving: false,
          message: saveFailedMessage,
        );
      }
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final postsPrivacyViewModelProvider =
    NotifierProvider.autoDispose<PostsPrivacyViewModel, PostsPrivacyState>(
      PostsPrivacyViewModel.new,
    );
