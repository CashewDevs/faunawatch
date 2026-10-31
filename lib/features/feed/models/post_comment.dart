/// A comment on a post, or a reply when nested inside another comment.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatarAsset,
    this.authorAvatarFilePath,
    this.authorAvatarUrl,
    this.imagePath,
    this.likeCount = 0,
    this.isLiked = false,
    this.isDisliked = false,
    this.isFromCreator = false,
    this.isLikedByCreator = false,
    this.replies = const [],
  });

  final String id;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? authorAvatarAsset;
  final String? authorAvatarFilePath;
  final String? authorAvatarUrl;

  /// Local path of an attached photo.
  final String? imagePath;
  final int likeCount;
  final bool isLiked;
  final bool isDisliked;
  final bool isFromCreator;
  final bool isLikedByCreator;
  final List<PostComment> replies;

  PostComment copyWith({
    int? likeCount,
    bool? isLiked,
    bool? isDisliked,
    List<PostComment>? replies,
  }) {
    return PostComment(
      id: id,
      authorName: authorName,
      text: text,
      createdAt: createdAt,
      authorAvatarAsset: authorAvatarAsset,
      authorAvatarFilePath: authorAvatarFilePath,
      authorAvatarUrl: authorAvatarUrl,
      imagePath: imagePath,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      isFromCreator: isFromCreator,
      isLikedByCreator: isLikedByCreator,
      replies: replies ?? this.replies,
    );
  }
}

enum CommentSortOrder { top, newest }

/// The comments of one post and how they are ordered.
class PostCommentsState {
  const PostCommentsState({
    this.comments = const [],
    this.sortOrder = CommentSortOrder.top,
    this.isLoading = false,
  });

  final List<PostComment> comments;
  final CommentSortOrder sortOrder;
  final bool isLoading;

  /// Comments and replies combined.
  int get totalCount => comments.fold(
    comments.length,
    (total, comment) => total + comment.replies.length,
  );

  PostCommentsState copyWith({
    List<PostComment>? comments,
    CommentSortOrder? sortOrder,
    bool? isLoading,
  }) {
    return PostCommentsState(
      comments: comments ?? this.comments,
      sortOrder: sortOrder ?? this.sortOrder,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Short age label for a comment, e.g. `37m` or `22h`.
String formatCommentAge(DateTime createdAt, DateTime now) {
  final age = now.difference(createdAt);
  if (age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 7) return '${age.inDays}d';
  return '${age.inDays ~/ 7}w';
}
