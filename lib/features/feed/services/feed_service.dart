import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';

/// Contract for the For You feed: approved reports, their likes and comments.
abstract interface class FeedService {
  /// Posts per page.
  static const pageSize = 10;

  /// Comments loaded for a post. Newest first; older ones are not paged yet.
  static const commentLimit = 100;

  /// Newest first. Pass the last post of the previous page as [before] to get
  /// the next, older page. Posts come with signed photo and avatar URLs.
  Future<List<FeedPost>> fetchPage({FeedPost? before});

  /// One approved post by report ID, or null when it is not (or no longer)
  /// approved.
  Future<FeedPost?> fetchPost(String postId);
  Future<void> like(String postId);
  Future<void> unlike(String postId);
  Future<List<PostComment>> fetchComments(String postId);

  /// Posts a comment as the signed-in user and returns it.
  Future<PostComment> addComment(String postId, String text);
}

/// Reads `community_feed()` and reads and writes `report_likes` and
/// `report_comments`; RLS decides who may do what.
class SupabaseFeedService implements FeedService {
  SupabaseFeedService(this._client);
  final SupabaseClient _client;

  /// Private photo URLs expire after one hour, like chat photos. A refresh
  /// signs them again.
  static const _urlLifetimeSeconds = 3600;
  static const _commentColumns =
      'id, user_id, body, created_at, '
      'profiles(username, full_name, display_name, avatar_path)';

  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to use the feed.'));

  @override
  Future<List<FeedPost>> fetchPage({FeedPost? before}) async {
    _userId;
    final rows = await _client.rpc(
      'community_feed',
      params: {
        'p_before_at': before?.feedAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': FeedService.pageSize,
      },
    );
    return _posts(rows as List);
  }

  @override
  Future<FeedPost?> fetchPost(String postId) async {
    _userId;
    final rows = await _client.rpc(
      'community_feed',
      params: {'p_report_id': postId, 'p_limit': 1},
    );
    final posts = await _posts(rows as List);
    return posts.firstOrNull;
  }

  Future<List<FeedPost>> _posts(List rows) {
    final avatars = <String, Future<String?>>{};
    return Future.wait(
      rows.map((raw) async {
        final post = FeedPost.fromJson(Map<String, dynamic>.from(raw as Map));
        final avatar = await _avatar(post.authorAvatarPath, avatars);
        final photos = await Future.wait(post.photoPaths.map(_photoUrl));
        return post.copyWith(
          authorAvatarAsset: avatar.asset,
          authorAvatarUrl: avatar.url,
          photoUrls: [for (final url in photos) ?url],
        );
      }),
    );
  }

  /// A photo that cannot be signed is left out rather than failing the page.
  Future<String?> _photoUrl(String path) async {
    try {
      return await _client.storage
          .from('report-images')
          .createSignedUrl(path, _urlLifetimeSeconds);
    } catch (_) {
      return null;
    }
  }

  /// The bundled preset for `preset:<name>`, else a signed URL for an uploaded
  /// picture. Authors repeat within a page, so each path is signed once.
  Future<({String? asset, String? url})> _avatar(
    String? path,
    Map<String, Future<String?>> signed,
  ) async {
    if (path == null || path.isEmpty) return (asset: null, url: null);
    final asset = AppAssets.spotterAvatars
        .where(
          (asset) =>
              path == asset ||
              path == 'preset:${asset.split('/').last.split('.').first}',
        )
        .firstOrNull;
    if (asset != null) return (asset: asset, url: null);
    if (path.startsWith('preset:') || path.startsWith('assets/')) {
      return (asset: null, url: null);
    }
    final url = await signed.putIfAbsent(path, () async {
      try {
        return await _client.storage
            .from('avatars')
            .createSignedUrl(path, _urlLifetimeSeconds);
      } catch (_) {
        return null;
      }
    });
    return (asset: null, url: url);
  }

  @override
  Future<void> like(String postId) async {
    final userId = _userId;
    // Liking twice is not an error: the second insert changes nothing.
    await _client
        .from('report_likes')
        .upsert(
          {'report_id': postId, 'user_id': userId},
          onConflict: 'report_id,user_id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> unlike(String postId) async {
    final userId = _userId;
    await _client
        .from('report_likes')
        .delete()
        .eq('report_id', postId)
        .eq('user_id', userId);
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    _userId;
    final rows = await _client
        .from('report_comments')
        .select(_commentColumns)
        .eq('report_id', postId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(FeedService.commentLimit);
    final avatars = <String, Future<String?>>{};
    return Future.wait(rows.map((row) => _comment(row, avatars)));
  }

  @override
  Future<PostComment> addComment(String postId, String text) async {
    final userId = _userId;
    final body = text.trim();
    if (body.isEmpty || body.length > PostComment.maxLength) {
      throw const FormatException(
        'Enter a comment of up to ${PostComment.maxLength} characters.',
      );
    }
    final row = await _client
        .from('report_comments')
        .insert({'report_id': postId, 'user_id': userId, 'body': body})
        .select(_commentColumns)
        .single();
    return _comment(row, {});
  }

  Future<PostComment> _comment(
    Map<String, dynamic> row,
    Map<String, Future<String?>> avatars,
  ) async {
    final comment = PostComment.fromJson(row);
    final avatar = await _avatar(comment.authorAvatarPath, avatars);
    return comment.withAvatar(asset: avatar.asset, url: avatar.url);
  }
}

/// Used while signed out or restoring the session: an empty feed, and no
/// client is kept.
class SignedOutFeedService implements FeedService {
  const SignedOutFeedService();
  Never _signIn() => throw const AuthException('Sign in to use the feed.');

  @override
  Future<List<FeedPost>> fetchPage({FeedPost? before}) async => const [];
  @override
  Future<FeedPost?> fetchPost(String postId) async => null;
  @override
  Future<void> like(String postId) async => _signIn();
  @override
  Future<void> unlike(String postId) async => _signIn();
  @override
  Future<List<PostComment>> fetchComments(String postId) async => const [];
  @override
  Future<PostComment> addComment(String postId, String text) async => _signIn();
}

/// Changes with the signed-in user, which rebuilds the feed ViewModel and
/// drops the previous user's posts and likes.
final feedServiceProvider = Provider<FeedService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutFeedService();
  }
  return SupabaseFeedService(ref.watch(supabaseClientProvider));
});
