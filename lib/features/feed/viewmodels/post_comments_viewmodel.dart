import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/post_comments_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';

export 'package:faunawatch/features/feed/models/post_comment.dart';

/// Manages the comments of the post identified by its family argument.
class PostCommentsViewModel extends FamilyNotifier<PostCommentsState, String> {
  @override
  PostCommentsState build(String arg) {
    _loadComments();
    return const PostCommentsState(isLoading: true);
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ref
          .read(postCommentsServiceProvider)
          .fetchComments(arg);
      state = state.copyWith(
        comments: _sorted(comments, state.sortOrder),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Adds a comment, or a reply when [parentId] is given. Returns whether
  /// anything was posted.
  Future<bool> addComment(
    String text, {
    String? parentId,
    String? imagePath,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePath == null) return false;

    final profile = ref.read(profileViewModelProvider).asData?.value;
    final username = profile?.username ?? '';
    try {
      final comment = await ref
          .read(postCommentsServiceProvider)
          .addComment(
            postId: arg,
            authorName: username.isEmpty ? 'You' : username,
            authorAvatarAsset: profile?.presetAvatar,
            authorAvatarFilePath: profile?.customImagePath,
            authorAvatarUrl: profile?.avatarUrl,
            text: trimmed,
            imagePath: imagePath,
          );
      state = state.copyWith(
        comments: parentId == null
            ? [comment, ...state.comments]
            : [
                for (final existing in state.comments)
                  existing.id == parentId
                      ? existing.copyWith(
                          replies: [...existing.replies, comment],
                        )
                      : existing,
              ],
      );
      return true;
    } catch (e) {
      debugPrint('PostCommentsViewModel: Failed to add comment: $e');
      return false;
    }
  }

  void toggleLike(String commentId) {
    _update(commentId, (comment) {
      final isLiked = !comment.isLiked;
      return comment.copyWith(
        isLiked: isLiked,
        isDisliked: false,
        likeCount: comment.likeCount + (isLiked ? 1 : -1),
      );
    });
  }

  void toggleDislike(String commentId) {
    _update(commentId, (comment) {
      final isDisliked = !comment.isDisliked;
      return comment.copyWith(
        isDisliked: isDisliked,
        isLiked: false,
        likeCount: comment.isLiked ? comment.likeCount - 1 : null,
      );
    });
  }

  /// Reorders once on selection, so reacting never moves a comment under the
  /// user's finger.
  void setSortOrder(CommentSortOrder sortOrder) {
    state = state.copyWith(
      sortOrder: sortOrder,
      comments: _sorted(state.comments, sortOrder),
    );
  }

  /// Opens the device picker and returns the selected photo's path, if any.
  Future<String?> pickImage() async {
    try {
      return await ref.read(imagePickerServiceProvider).pickImage();
    } catch (e) {
      debugPrint('PostCommentsViewModel: Failed to pick image: $e');
      return null;
    }
  }

  void _update(String commentId, PostComment Function(PostComment) change) {
    PostComment apply(PostComment comment) {
      if (comment.id == commentId) return change(comment);
      return comment.copyWith(replies: comment.replies.map(apply).toList());
    }

    state = state.copyWith(comments: state.comments.map(apply).toList());
  }

  List<PostComment> _sorted(
    List<PostComment> comments,
    CommentSortOrder sortOrder,
  ) {
    return [...comments]..sort(
      (a, b) => switch (sortOrder) {
        CommentSortOrder.top => b.likeCount.compareTo(a.likeCount),
        CommentSortOrder.newest => b.createdAt.compareTo(a.createdAt),
      },
    );
  }
}

/// Provider family exposing [PostCommentsViewModel] by post ID. Kept alive so
/// comments survive closing the sheet.
final postCommentsViewModelProvider =
    NotifierProviderFamily<PostCommentsViewModel, PostCommentsState, String>(
      PostCommentsViewModel.new,
    );
