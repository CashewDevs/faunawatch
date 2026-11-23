import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ProfileTagService {
  Future<bool> saveTag(ProfileTag? tag);
}

/// Persists the current account's chosen tag.
class SupabaseProfileTagService implements ProfileTagService {
  const SupabaseProfileTagService(this._client, this._userId);
  final SupabaseClient _client;
  final String _userId;

  void _requireAccount() {
    if (_client.auth.currentUser?.id != _userId) {
      throw const AuthException('Sign in to manage your profile tag.');
    }
  }

  @override
  Future<bool> saveTag(ProfileTag? tag) async {
    _requireAccount();
    final rows = await _client
        .from('profiles')
        .update({'profile_tag': tag?.value})
        .eq('id', _userId)
        .select('id');
    return rows.isNotEmpty;
  }
}

class SignedOutProfileTagService implements ProfileTagService {
  const SignedOutProfileTagService();
  @override
  Future<bool> saveTag(ProfileTag? tag) async => false;
}

final profileTagServiceProvider = Provider<ProfileTagService>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null) return const SignedOutProfileTagService();
  return SupabaseProfileTagService(ref.watch(supabaseClientProvider), userId);
});
