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

  final SupabaseClient _client;

  @override
  Future<ProfileData> loadProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select(
          'username, full_name, display_name, avatar_path, banner_asset, banner_color',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return const ProfileData();

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
    // Bio persistence still requires a schema decision; keep it empty.
    return ProfileData(
      username: name ?? '',
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
