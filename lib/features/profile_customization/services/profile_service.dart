import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// Service contract for saving and managing user profile setup data.
abstract interface class ProfileService {
  /// Updates [display_name] in the signed-in user's profiles row.
  Future<bool> saveProfile({required String username, required String bio});

  /// Saves the profile picture.
  ///
  /// If [customImagePath] is provided, the file is uploaded to the `avatars`
  /// storage bucket at `{userId}/{filename}` and the resulting storage path
  /// is written to [profiles.avatar_path].
  ///
  /// If [presetAvatar] is provided (a local asset path), the value is stored
  /// directly as [profiles.avatar_path] as a lightweight identifier.
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  });

  /// Saves the profile banner preference.
  // TODO(profile-banner): profiles table has no banner column yet.
  // Add a migration (e.g. banner_asset text, banner_color int) before
  // implementing this. For now this is a no-op.
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue});
}

/// Supabase-backed implementation of [ProfileService].
class SupabaseProfileService implements ProfileService {
  const SupabaseProfileService(this._client);

  final SupabaseClient _client;

  static const _avatarsBucket = 'avatars';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<bool> saveProfile({
    required String username,
    required String bio,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    await _client
        .from('profiles')
        .update({'display_name': username.trim()})
        .eq('id', userId);
    return true;
  }

  @override
  Future<bool> saveProfilePicture({
    String? presetAvatar,
    String? customImagePath,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    String avatarPath;

    if (customImagePath != null) {
      // Upload the local file to the avatars bucket.
      final file = File(customImagePath);
      final fileName = file.uri.pathSegments.last;
      final storagePath = '$userId/$fileName';

      await _client.storage
          .from(_avatarsBucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      avatarPath = storagePath;
    } else if (presetAvatar != null) {
      // Store the preset asset identifier directly — no upload needed.
      avatarPath = presetAvatar;
    } else {
      return false;
    }

    await _client
        .from('profiles')
        .update({'avatar_path': avatarPath})
        .eq('id', userId);
    return true;
  }

  @override
  Future<bool> saveProfileBanner({String? bannerAsset, int? colorValue}) async {
    // TODO(profile-banner): no-op until a migration adds banner columns.
    return true;
  }
}

/// Riverpod provider exposing [ProfileService].
final profileServiceProvider = Provider<ProfileService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseProfileService(client);
});
