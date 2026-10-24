import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/services/profile_storage_service.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_banner_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_picture_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/viewmodels/profile_setup_viewmodel.dart';

/// ViewModel managing presentation state and modifications for the user profile.
class ProfileViewModel extends Notifier<ProfileData> {
  late final ProfileStorageService _storageService;

  @override
  ProfileData build() {
    _storageService = ref.watch(profileStorageServiceProvider);

    final setupState = ref.watch(profileSetupViewModelProvider);
    final pictureState = ref.watch(profilePictureViewModelProvider);
    final bannerState = ref.watch(profileBannerViewModelProvider);

    final username = setupState.username.trim().isNotEmpty
        ? setupState.username.trim()
        : 'tweetybird';

    final bio = setupState.bio.trim().isNotEmpty
        ? setupState.bio.trim()
        : 'pls dont be inluv wt sum1 else';

    final presetAvatar =
        pictureState.selectedPresetAvatar ??
        (pictureState.customImagePath == null ? AppAssets.avatarTweety : null);

    final customImagePath = pictureState.customImagePath;

    final bannerAsset = bannerState.selectedBanner;
    final bannerColorValue =
        bannerState.selectedColor?.toARGB32() ??
        (bannerAsset == null ? 0xFFBCE7B4 : null);

    return ProfileData(
      username: username,
      bio: bio,
      presetAvatar: presetAvatar,
      customImagePath: customImagePath,
      bannerAsset: bannerAsset,
      bannerColorValue: bannerColorValue,
    );
  }

  /// Updates profile properties in memory.
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
    state = state.copyWith(
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
    );
  }

  /// Persists the updated profile data via [ProfileStorageService].
  Future<bool> save() async {
    return _storageService.saveProfile(state);
  }
}

/// Riverpod provider exposing [ProfileViewModel].
final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileData>(ProfileViewModel.new);
