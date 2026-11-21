import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PublicProfileService {
  static const pageSize = 12;
  Future<ProfileData?> fetchProfile(String userId);
  Future<List<FeedPost>> fetchPosts(
    String userId, {
    FeedPost? before,
    ReportCategory? category,
  });
}

/// Reads public identity and the approved-only, author-filtered gallery RPC.
class SupabasePublicProfileService implements PublicProfileService {
  SupabasePublicProfileService(this._client)
    : _profiles = SupabaseProfileReaderService(_client),
      _feed = SupabaseFeedService(_client);

  final SupabaseClient _client;
  final SupabaseProfileReaderService _profiles;
  final SupabaseFeedService _feed;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw const AuthException('Sign in to view community profiles.');
    }
  }

  @override
  Future<ProfileData?> fetchProfile(String userId) {
    _requireSession();
    return _profiles.findProfile(userId);
  }

  @override
  Future<List<FeedPost>> fetchPosts(
    String userId, {
    FeedPost? before,
    ReportCategory? category,
  }) async {
    _requireSession();
    final rows = await _client.rpc(
      'public_profile_gallery',
      params: {
        'p_user_id': userId,
        'p_before_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': PublicProfileService.pageSize,
        'p_category': category?.value,
      },
    );
    return _feed.resolvePosts(rows as List);
  }
}

class SignedOutPublicProfileService implements PublicProfileService {
  const SignedOutPublicProfileService();
  @override
  Future<ProfileData?> fetchProfile(String userId) async => null;
  @override
  Future<List<FeedPost>> fetchPosts(
    String userId, {
    FeedPost? before,
    ReportCategory? category,
  }) async => const [];
}

final publicProfileServiceProvider = Provider<PublicProfileService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutPublicProfileService();
  }
  return SupabasePublicProfileService(ref.watch(supabaseClientProvider));
});
