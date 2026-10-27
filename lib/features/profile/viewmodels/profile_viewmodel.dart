import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_reader_service.dart';
import 'package:faunawatch/features/profile/services/profile_storage_service.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

/// Loads the current account's persisted profile and exposes editing state.
class ProfileViewModel extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() async {
    final userId = await ref.watch(currentUserIdProvider.future);
    if (userId == null) return const ProfileData();
    return ref.watch(profileReaderServiceProvider).loadProfile(userId);
  }

  void updateProfile({
    String? username,
    String? bio,
    String? presetAvatar,
    String? customImagePath,
    String? bannerAsset,
    int? bannerColorValue,
    bool clearPreset = false,
    bool clearCustom = false,
    bool clearBanner = false,
    bool clearColor = false,
  }) {
    final profile = state.asData?.value;
    if (profile == null) return;
    state = AsyncData(
      profile.copyWith(
        username: username,
        bio: bio,
        presetAvatar: presetAvatar,
        customImagePath: customImagePath,
        bannerAsset: bannerAsset,
        bannerColorValue: bannerColorValue,
        clearPresetAvatar: clearPreset,
        clearCustomImage: clearCustom,
        clearBannerAsset: clearBanner,
        clearBannerColor: clearColor,
      ),
    );
  }

  Future<bool> save() async {
    final profile = state.asData?.value;
    if (profile == null) return false;
    try {
      final saved = await ref
          .read(profileStorageServiceProvider)
          .saveProfile(profile);
      if (!saved) return false;
      return await ref
          .read(profileServiceProvider)
          .saveProfileBanner(
            bannerAsset: profile.bannerAsset,
            colorValue: profile.bannerColorValue,
          );
    } catch (_) {
      return false;
    }
  }
}

final profileViewModelProvider =
    AsyncNotifierProvider<ProfileViewModel, ProfileData>(ProfileViewModel.new);
