import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/profile_customization/models/profile_picture_state.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

export 'package:faunawatch/features/profile_customization/models/profile_picture_state.dart';

/// ViewModel managing spotter avatar selection and custom photo upload.
class ProfilePictureViewModel extends Notifier<ProfilePictureState> {
  late final ProfileService _profileService;
  late final ImagePickerService _imagePickerService;

  @override
  ProfilePictureState build() {
    _profileService = ref.watch(profileServiceProvider);
    _imagePickerService = ref.watch(imagePickerServiceProvider);
    return const ProfilePictureState();
  }

  /// Selects one of the preset spotter avatars, deselecting any custom upload.
  void selectPresetAvatar(String assetPath) {
    state = state.copyWith(selectedPresetAvatar: assetPath, clearCustom: true);
  }

  /// Triggers device file/gallery picker to choose a custom profile photo.
  Future<void> pickCustomImage() async {
    try {
      final pickedPath = await _imagePickerService.pickImage();
      if (pickedPath != null && pickedPath.isNotEmpty) {
        state = state.copyWith(customImagePath: pickedPath, clearPreset: true);
      }
    } catch (e) {
      debugPrint('ProfilePictureViewModel: Failed to pick image: $e');
      state = state.copyWith(
        errorMessage: 'Unable to select image. Please try again.',
      );
    }
  }

  /// Submits the chosen avatar / custom picture.
  Future<bool> submit() async {
    if (!state.isContinueEnabled || state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final success = await _profileService.saveProfilePicture(
        presetAvatar: state.selectedPresetAvatar,
        customImagePath: state.customImagePath,
      );
      state = state.copyWith(isSubmitting: false);
      return success;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save profile picture.',
      );
      return false;
    }
  }
}

/// Riverpod provider exposing [ProfilePictureViewModel] and [ProfilePictureState].
final profilePictureViewModelProvider =
    NotifierProvider<ProfilePictureViewModel, ProfilePictureState>(
      ProfilePictureViewModel.new,
    );
