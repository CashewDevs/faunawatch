import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which posts the user has liked during this session.
class PostLikesViewModel extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String postId) {
    state = state.contains(postId)
        ? ({...state}..remove(postId))
        : {...state, postId};
  }
}

final postLikesViewModelProvider =
    NotifierProvider<PostLikesViewModel, Set<String>>(PostLikesViewModel.new);
