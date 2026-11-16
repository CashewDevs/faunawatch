import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/gallery/models/gallery_post_state.dart';

/// Loads a full own post and manages its actions without changing feed state
/// or the shell destination. All account changes discard the previous result.
class GalleryPostViewModel
    extends AutoDisposeFamilyNotifier<GalleryPostState, String> {
  late FeedService _service;
  String? _ownerId;
  int _generation = 0;
  bool _liking = false;
  bool _disposed = false;

  @override
  GalleryPostState build(String arg) {
    _service = ref.watch(feedServiceProvider);
    _ownerId = ref.watch(currentUserIdProvider).valueOrNull;
    final generation = ++_generation;
    _liking = false;
    _disposed = false;
    ref.onDispose(() {
      _generation++;
      _disposed = true;
    });
    Future.microtask(() => _load(generation));
    return const GalleryPostState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    final ownerId = _ownerId;
    if (ownerId == null) {
      state = const GalleryPostState();
      return;
    }
    try {
      final post = await _service.fetchPost(arg);
      if (generation != _generation) return;
      state = GalleryPostState(post: post?.authorId == ownerId ? post : null);
    } catch (_) {
      if (generation == _generation) {
        state = const GalleryPostState(hasError: true);
      }
    }
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    state = const GalleryPostState(isLoading: true);
    await _load(++_generation);
  }

  Future<void> toggleLike() async {
    final before = state.post;
    if (before == null || _liking) return;
    _liking = true;
    final generation = _generation;
    final liked = !before.likedByMe;
    state = state.copyWith(
      post: before.copyWith(
        likedByMe: liked,
        likeCount: math.max(0, before.likeCount + (liked ? 1 : -1)),
      ),
    );
    try {
      await (liked ? _service.like(arg) : _service.unlike(arg));
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          post: state.post?.copyWith(
            likedByMe: before.likedByMe,
            likeCount: before.likeCount,
          ),
          message: 'Could not update your like.',
        );
      }
    } finally {
      if (generation == _generation) _liking = false;
    }
  }

  /// The sheet owns comment requests; this viewer keeps its local count in
  /// step, preserving larger totals when only the latest 100 are loaded.
  void commentsChanged(PostCommentsState? previous, PostCommentsState next) {
    if (_disposed) return;
    final post = state.post;
    if (post == null || next.isLoading || next.hasError) return;
    if (next.comments.length < FeedService.commentLimit) {
      state = state.copyWith(
        post: post.copyWith(commentCount: next.comments.length),
      );
    } else if (previous != null &&
        previous.isSending &&
        !next.isSending &&
        next.sendError == null &&
        next.comments.length > previous.comments.length) {
      state = state.copyWith(
        post: post.copyWith(
          commentCount:
              post.commentCount +
              next.comments.length -
              previous.comments.length,
        ),
      );
    }
  }

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final galleryPostViewModelProvider = NotifierProvider.autoDispose
    .family<GalleryPostViewModel, GalleryPostState, String>(
      GalleryPostViewModel.new,
    );
