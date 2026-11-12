import 'dart:async';

import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';

/// A feed post with test defaults. `feedAt` falls one minute per [index].
FeedPost testPost(
  String id, {
  int index = 0,
  String title = 'Philippine Eagle',
  String description = 'Seen near the ridge.',
  String authorName = 'spotter_one',
  String? placeName = 'Lusod, Kabayan, Benguet',
  int likeCount = 0,
  bool likedByMe = false,
  int commentCount = 0,
  List<String> photoUrls = const [],
  SeverityLevel? severity,
  String? aiSpeciesGuess,
  bool possibleInvasive = false,
  String? avatarAsset,
}) {
  final base = DateTime.utc(2026, 11, 12, 8);
  return FeedPost(
    id: id,
    title: title,
    createdAt: base.subtract(Duration(minutes: index + 5)),
    feedAt: base.subtract(Duration(minutes: index)),
    authorId: 'author-$id',
    authorName: authorName,
    description: description,
    placeName: placeName,
    likeCount: likeCount,
    likedByMe: likedByMe,
    commentCount: commentCount,
    photoUrls: photoUrls,
    severity: severity,
    aiSpeciesGuess: aiSpeciesGuess,
    possibleInvasive: possibleInvasive,
    authorAvatarAsset: avatarAsset,
  );
}

PostComment testComment(
  String id, {
  String authorName = 'trail_walker',
  String text = 'Great spot!',
  DateTime? createdAt,
}) => PostComment(
  id: id,
  authorId: 'commenter-$id',
  authorName: authorName,
  text: text,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 12, 9),
);

/// In-memory [FeedService]. Pages follow [posts] by keyset like the RPC.
class FakeFeedService implements FeedService {
  FakeFeedService({
    List<FeedPost> posts = const [],
    List<PostComment> comments = const [],
  }) : posts = [...posts],
       comments = [...comments];

  List<FeedPost> posts;
  List<PostComment> comments;

  /// Approved posts that [fetchPost] finds but pages do not list, e.g. ones
  /// further back than the pages loaded so far.
  List<FeedPost> unlisted = [];

  /// The `before` argument of every page request, in order.
  final pageRequests = <FeedPost?>[];
  final likes = <String>[], unlikes = <String>[];
  final added = <String>[];
  Object? pageError, likeError, commentsError, addError;

  /// While set, likes and pages wait for it.
  Completer<void>? likeGate, pageGate;

  @override
  Future<List<FeedPost>> fetchPage({FeedPost? before}) async {
    pageRequests.add(before);
    await pageGate?.future;
    if (pageError != null) throw pageError!;
    final start = before == null
        ? 0
        : posts.indexWhere((post) => post.id == before.id) + 1;
    return posts.skip(start).take(FeedService.pageSize).toList();
  }

  @override
  Future<FeedPost?> fetchPost(String postId) async =>
      [...posts, ...unlisted].where((post) => post.id == postId).firstOrNull;

  @override
  Future<void> like(String postId) async {
    likes.add(postId);
    await likeGate?.future;
    if (likeError != null) throw likeError!;
  }

  @override
  Future<void> unlike(String postId) async {
    unlikes.add(postId);
    await likeGate?.future;
    if (likeError != null) throw likeError!;
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    if (commentsError != null) throw commentsError!;
    return comments;
  }

  @override
  Future<PostComment> addComment(String postId, String text) async {
    if (addError != null) throw addError!;
    added.add(text);
    return testComment(
      'new-${added.length}',
      authorName: 'me',
      text: text.trim(),
    );
  }
}
