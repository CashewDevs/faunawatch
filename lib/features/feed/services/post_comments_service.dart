import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';

/// Contract for loading and creating post comments.
abstract interface class PostCommentsService {
  Future<List<PostComment>> fetchComments(String postId);
  Future<PostComment> addComment({
    required String postId,
    required String authorName,
    required String text,
    String? authorAvatarAsset,
    String? authorAvatarFilePath,
    String? authorAvatarUrl,
    String? imagePath,
  });
}

/// Local implementation for the sample posts. Comments last for the session.
///
/// Sample posts are not `reports` rows, so `report_comments` cannot hold them,
/// and that table has no replies, reactions, or image attachments yet.
class LocalPostCommentsService implements PostCommentsService {
  const LocalPostCommentsService();

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    if (postId != sampleMapPost.id) return const [];
    final now = DateTime.now();
    return [
      PostComment(
        id: 'sample-comment-1',
        authorName: 'trail_walker',
        authorAvatarAsset: AppAssets.avatarBunny,
        text: 'Great spot! Which part of the trail was this?',
        createdAt: now.subtract(const Duration(hours: 22)),
        likeCount: 17,
        isLikedByCreator: true,
        replies: [
          PostComment(
            id: 'sample-comment-1-reply-1',
            authorName: sampleMapPost.author,
            authorAvatarAsset: sampleMapPost.authorAvatarAsset,
            text: 'Thanks! It was close to the main walking loop.',
            createdAt: now.subtract(const Duration(hours: 21)),
            likeCount: 20,
            isFromCreator: true,
          ),
          PostComment(
            id: 'sample-comment-1-reply-2',
            authorName: 'canopy_kid',
            authorAvatarAsset: AppAssets.avatarJerry,
            text: 'I want to walk there this weekend.',
            createdAt: now.subtract(const Duration(hours: 5)),
            likeCount: 2,
          ),
        ],
      ),
      PostComment(
        id: 'sample-comment-2',
        authorName: 'bird_notes',
        authorAvatarAsset: AppAssets.avatarTweety,
        text: 'Did it stay long before flying off?',
        createdAt: now.subtract(const Duration(minutes: 37)),
        likeCount: 1,
        isLikedByCreator: true,
        replies: [
          PostComment(
            id: 'sample-comment-2-reply-1',
            authorName: 'trail_walker',
            authorAvatarAsset: AppAssets.avatarBunny,
            text: 'Same question!',
            createdAt: now.subtract(const Duration(minutes: 12)),
          ),
        ],
      ),
      PostComment(
        id: 'sample-comment-3',
        authorName: 'green_ridge',
        authorAvatarAsset: AppAssets.avatarGrizz,
        text: 'Love seeing posts from around here.',
        createdAt: now.subtract(const Duration(hours: 22)),
        likeCount: 1,
      ),
    ];
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required String authorName,
    required String text,
    String? authorAvatarAsset,
    String? authorAvatarFilePath,
    String? authorAvatarUrl,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    return PostComment(
      id: 'comment-${now.microsecondsSinceEpoch}',
      authorName: authorName,
      authorAvatarAsset: authorAvatarAsset,
      authorAvatarFilePath: authorAvatarFilePath,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      imagePath: imagePath,
      createdAt: now,
    );
  }
}

final postCommentsServiceProvider = Provider<PostCommentsService>((ref) {
  return const LocalPostCommentsService();
});
