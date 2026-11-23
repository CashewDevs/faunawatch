import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
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

  /// Picks a custom avatar image from the device gallery via [ImagePickerService].
  Future<String?> pickCustomAvatar() async {
    try {
      final path = await ref.read(imagePickerServiceProvider).pickImage();
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  void restoreProfile(ProfileData profile) {
    state = AsyncData(profile);
  }

  /// Called only after the dedicated tag service confirms persistence.
  void updateProfileTag(ProfileTag? tag) {
    final profile = state.asData?.value;
    if (profile == null) return;
    state = AsyncData(
      profile.copyWith(profileTag: tag, clearProfileTag: tag == null),
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
      final profileService = ref.read(profileServiceProvider);
      final identitySaved = await profileService.saveProfile(
        username: profile.username,
        bio: profile.bio,
      );
      if (!identitySaved) return false;
      if (profile.customImagePath != null || profile.presetAvatar != null) {
        final pictureSaved = await profileService.saveProfilePicture(
          presetAvatar: profile.presetAvatar,
          customImagePath: profile.customImagePath,
        );
        if (!pictureSaved) return false;
      }
      return await profileService.saveProfileBanner(
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
