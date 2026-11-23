import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ProfileTagService {
  Future<ProfileTagActivity> fetchActivity();
  Future<bool> saveTag(ProfileTag? tag);
}

/// Reads the current account's aggregate counts and persists its confirmed tag.
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
  Future<ProfileTagActivity> fetchActivity() async {
    _requireAccount();
    final rows = await _client.rpc('my_profile_tag_activity') as List;
    if (rows.length != 1 || rows.single is! Map) {
      throw const FormatException('Invalid profile activity summary.');
    }
    return ProfileTagActivity.fromJson(
      Map<String, dynamic>.from(rows.single as Map),
    );
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
  Future<ProfileTagActivity> fetchActivity() async => const ProfileTagActivity(
    approvedReports: 0,
    dogReports: 0,
    catReports: 0,
  );
  @override
  Future<bool> saveTag(ProfileTag? tag) async => false;
}

final profileTagServiceProvider = Provider<ProfileTagService>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null) return const SignedOutProfileTagService();
  return SupabaseProfileTagService(ref.watch(supabaseClientProvider), userId);
});
