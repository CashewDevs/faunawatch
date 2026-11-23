import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';

abstract interface class ProfileReaderService {
  Future<ProfileData> loadProfile(String userId);
}

/// Reads persisted identity independently of the onboarding form state.
class SupabaseProfileReaderService implements ProfileReaderService {
  const SupabaseProfileReaderService(this._client);

  static const _profileColumns = [
    'username',
    'full_name',
    'display_name',
    'bio',
    'avatar_path',
    'banner_asset',
    'banner_color',
    'posts_private',
    'profile_tag',
  ];

  /// Columns added by later migrations. When a database doesn't have one
  /// yet, the profile is read without it (bio empty, posts not private).
  static const _newerColumns = {'bio', 'posts_private', 'profile_tag'};

  final SupabaseClient _client;

  /// The newer column [error] says is missing, if any.
  static String? _missingNewerColumn(
    PostgrestException error,
    List<String> columns,
  ) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    final hasMissingColumnSignal =
        code == '42703' ||
        code == 'PGRST204' ||
        message.contains('42703') ||
        message.contains('pgrst204') ||
        message.contains('does not exist') ||
        message.contains('schema cache');
    if (!hasMissingColumnSignal) return null;
    return columns
        .where(_newerColumns.contains)
        .where(message.contains)
        .firstOrNull;
  }

  @override
  Future<ProfileData> loadProfile(String userId) async =>
      await findProfile(userId) ?? const ProfileData();

  Future<Map<String, dynamic>?> _fetchProfileRow(String userId) async {
    final columns = [..._profileColumns];
    while (true) {
      try {
        return await _client
            .from('profiles')
            .select(columns.join(', '))
            .eq('id', userId)
            .maybeSingle();
      } on PostgrestException catch (error) {
        final missing = _missingNewerColumn(error, columns);
        if (missing == null) rethrow;
        columns.remove(missing);
      }
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
      profileTag: ProfileTag.fromValue(row['profile_tag']),
      presetAvatar: preset,
      avatarUrl: avatarUrl,
      bannerAsset: row['banner_asset'] as String?,
      bannerColorValue: (row['banner_color'] as num?)?.toInt(),
      postsPrivate: row['posts_private'] == true,
    );
  }
}

final profileReaderServiceProvider = Provider<ProfileReaderService>((ref) {
  return SupabaseProfileReaderService(ref.watch(supabaseClientProvider));
});
