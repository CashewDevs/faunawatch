import 'package:faunawatch/features/feed/models/feed_post.dart';

/// One row of `report_comments` with its author.
///
/// The table has no replies, reactions or image attachments, so neither does
/// this model.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatarPath,
    this.authorAvatarAsset,
    this.authorAvatarUrl,
  });

  /// Longest comment the app sends.
  static const maxLength = 1000;

  final String id, authorId, authorName, text;
  final DateTime createdAt;

  /// `profiles.avatar_path`: `preset:<name>` or a path in the avatars bucket.
  final String? authorAvatarPath;
  final String? authorAvatarAsset, authorAvatarUrl;

  /// Reads a row selected as
  /// `id, user_id, body, created_at, profiles(username, full_name, display_name, avatar_path)`.
  factory PostComment.fromJson(Map<String, dynamic> row) {
    final profile = row['profiles'];
    String? field(String key) {
      final text = profile is Map ? profile[key]?.toString().trim() : null;
      return text == null || text.isEmpty ? null : text;
    }

    return PostComment(
      id: row['id'] as String,
      authorId: row['user_id'] as String,
      authorName:
          field('username') ??
          field('full_name') ??
          field('display_name') ??
          FeedPost.fallbackAuthorName,
      text: (row['body'] as String? ?? '').trim(),
      createdAt: DateTime.parse(row['created_at'] as String),
      authorAvatarPath: field('avatar_path'),
    );
  }

  PostComment withAvatar({String? asset, String? url}) => PostComment(
    id: id,
    authorId: authorId,
    authorName: authorName,
    text: text,
    createdAt: createdAt,
    authorAvatarPath: authorAvatarPath,
    authorAvatarAsset: asset,
    authorAvatarUrl: url,
  );
}

/// The comments of one post, newest first.
class PostCommentsState {
  const PostCommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.hasError = false,
    this.isSending = false,
    this.sendError,
  });

  final List<PostComment> comments;
  final bool isLoading;

  /// Loading failed and nothing is shown yet.
  final bool hasError;
  final bool isSending;

  /// Why the last comment could not be posted, if it could not.
  final String? sendError;

  PostCommentsState copyWith({
    List<PostComment>? comments,
    bool? isLoading,
    bool? hasError,
    bool? isSending,
    String? sendError,
    bool clearSendError = false,
  }) {
    return PostCommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      isSending: isSending ?? this.isSending,
      sendError: clearSendError ? null : sendError ?? this.sendError,
    );
  }
}
