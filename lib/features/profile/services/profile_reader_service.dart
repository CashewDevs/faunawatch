import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';

abstract interface class ProfileReaderService {
  Future<ProfileData> loadProfile(String userId);
}

/// Reads persisted identity independently of the onboarding form state.
class SupabaseProfileReaderService implements ProfileReaderService {
  const SupabaseProfileReaderService(this._client);

  static const _profileColumnsWithBio =
      'username, full_name, display_name, bio, avatar_path, banner_asset, banner_color';
  static const _profileColumnsWithoutBio =
      'username, full_name, display_name, avatar_path, banner_asset, banner_color';

  final SupabaseClient _client;

  static bool _isMissingBioColumn(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    final hasMissingColumnSignal =
        code == '42703' ||
        code == 'PGRST204' ||
        message.contains('42703') ||
        message.contains('pgrst204') ||
        message.contains('does not exist') ||
        message.contains('schema cache');
    return hasMissingColumnSignal && message.contains('bio');
  }

  @override
  Future<ProfileData> loadProfile(String userId) async =>
      await findProfile(userId) ?? const ProfileData();

  Future<Map<String, dynamic>?> _fetchProfileRow(String userId) async {
    try {
      return await _client
          .from('profiles')
          .select(_profileColumnsWithBio)
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (!_isMissingBioColumn(error)) rethrow;
      return await _client
          .from('profiles')
          .select(_profileColumnsWithoutBio)
          .eq('id', userId)
          .maybeSingle();
    }
  }

  /// Public identity, or null when the account no longer exists.
  Future<ProfileData?> findProfile(String userId) async {
    final row = await _fetchProfileRow(userId);
    if (row == null) return null;

    final name = ['username', 'full_name', 'display_name']
        .map((key) => (row[key] as String?)?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final avatarPath = row['avatar_path'] as String?;
    String? preset;
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      for (final asset in AppAssets.spotterAvatars) {
        final name = asset.split('/').last.split('.').first;
        if (avatarPath == asset || avatarPath == 'preset:$name') {
          preset = asset;
          break;
        }
      }
      if (preset == null &&
          !avatarPath.startsWith('preset:') &&
          !avatarPath.startsWith('assets/')) {
        avatarUrl = await _client.storage
            .from('avatars')
            .createSignedUrl(avatarPath, 3600);
      }
    }
    return ProfileData(
      username: name ?? '',
      bio: (row['bio'] as String?)?.trim() ?? '',
      presetAvatar: preset,
      avatarUrl: avatarUrl,
      bannerAsset: row['banner_asset'] as String?,
      bannerColorValue: (row['banner_color'] as num?)?.toInt(),
    );
  }
}

final profileReaderServiceProvider = Provider<ProfileReaderService>((ref) {
  return SupabaseProfileReaderService(ref.watch(supabaseClientProvider));
});
