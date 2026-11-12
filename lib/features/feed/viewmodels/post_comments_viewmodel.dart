import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';

export 'package:faunawatch/features/feed/models/post_comment.dart';

/// Loads and adds the comments of the post identified by its family argument.
///
/// Auto-disposed, so the comments are loaded again each time the sheet opens.
class PostCommentsViewModel
    extends AutoDisposeFamilyNotifier<PostCommentsState, String> {
  late FeedService _service;
  var _disposed = false;

  @override
  PostCommentsState build(String arg) {
    _service = ref.watch(feedServiceProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const PostCommentsState(isLoading: true);
  }

  /// Loads the comments, newest first. A failure keeps what is already shown.
  Future<void> load() async {
    try {
      final comments = await _service.fetchComments(arg);
      if (_disposed) return;
      state = state.copyWith(
        comments: comments,
        isLoading: false,
        hasError: false,
      );
      // Every comment is loaded, so the post's count can be made exact.
      if (comments.length < FeedService.commentLimit) {
        ref
            .read(feedViewModelProvider.notifier)
            .setCommentCount(arg, comments.length);
      }
    } catch (e) {
      debugPrint('PostCommentsViewModel: Failed to load comments: $e');
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        hasError: state.comments.isEmpty,
      );
    }
  }

  /// Adds a comment first in the list. Returns whether it was posted; when it
  /// was not, [PostCommentsState.sendError] says why and the text is kept by
  /// the caller.
  Future<bool> addComment(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return false;
    final feed = ref.read(feedViewModelProvider.notifier);
    state = state.copyWith(isSending: true, clearSendError: true);
    try {
      final comment = await _service.addComment(arg, trimmed);
      feed.adjustCommentCount(arg, 1);
      if (_disposed) return true;
      state = state.copyWith(
        comments: [comment, ...state.comments],
        isSending: false,
      );
      return true;
    } on FormatException catch (e) {
      if (!_disposed) {
        state = state.copyWith(isSending: false, sendError: e.message);
      }
      return false;
    } catch (e) {
      debugPrint('PostCommentsViewModel: Failed to add comment: $e');
      if (!_disposed) {
        state = state.copyWith(
          isSending: false,
          sendError: 'Could not post your comment. Please try again.',
        );
      }
      return false;
    }
  }

  void clearSendError() => state = state.copyWith(clearSendError: true);
}

final postCommentsViewModelProvider = NotifierProvider.autoDispose
    .family<PostCommentsViewModel, PostCommentsState, String>(
      PostCommentsViewModel.new,
    );
