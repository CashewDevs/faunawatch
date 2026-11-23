import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and saves the signed-in user's "Private posts" setting.
abstract interface class PostsPrivacyService {
  /// Whether the user's posts are hidden from visitors to their profile.
  Future<bool> load();

  /// Saves [isPrivate] and returns the value the server stored.
  Future<bool> save(bool isPrivate);
}

/// Stores the setting on the user's own `profiles` row. Saving goes through
/// `set_posts_private`, which (unlike a normal profile edit) still works
/// while the account is suspended.
class SupabasePostsPrivacyService implements PostsPrivacyService {
  const SupabasePostsPrivacyService(this._client);
  final SupabaseClient _client;

  String _userId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to change this setting.');
    }
    return userId;
  }

  @override
  Future<bool> load() async {
    final row = await _client
        .from('profiles')
        .select('posts_private')
        .eq('id', _userId())
        .maybeSingle();
    return row?['posts_private'] == true;
  }

  @override
  Future<bool> save(bool isPrivate) async {
    _userId();
    final saved = await _client.rpc(
      'set_posts_private',
      params: {'p_private': isPrivate},
    );
    return saved == true;
  }
}

class SignedOutPostsPrivacyService implements PostsPrivacyService {
  const SignedOutPostsPrivacyService();
  @override
  Future<bool> load() async => false;
  @override
  Future<bool> save(bool isPrivate) async =>
      throw const AuthException('Sign in to change this setting.');
}

final postsPrivacyServiceProvider = Provider<PostsPrivacyService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutPostsPrivacyService();
  }
  return SupabasePostsPrivacyService(ref.watch(supabaseClientProvider));
});
