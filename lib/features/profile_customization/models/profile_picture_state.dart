/// Immutable state representing profile picture selection.
class ProfilePictureState {
  const ProfilePictureState({
    this.selectedPresetAvatar,
    this.customImagePath,
    this.isSubmitting = false,
    this.errorMessage,
  });

  /// The asset path of the selected spotter avatar, if one is chosen.
  final String? selectedPresetAvatar;

  /// The local file path of a custom uploaded profile picture, if chosen.
  final String? customImagePath;

  final bool isSubmitting;
  final String? errorMessage;

  /// Whether a custom image is currently selected as the profile picture.
  bool get isCustomImageSelected => customImagePath != null;

  /// Whether an avatar or custom image is chosen, activating the Continue button.
  bool get isContinueEnabled =>
      selectedPresetAvatar != null || customImagePath != null;

  ProfilePictureState copyWith({
    String? selectedPresetAvatar,
    String? customImagePath,
    bool clearPreset = false,
    bool clearCustom = false,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ProfilePictureState(
      selectedPresetAvatar: clearPreset
          ? null
          : (selectedPresetAvatar ?? this.selectedPresetAvatar),
      customImagePath: clearCustom
          ? null
          : (customImagePath ?? this.customImagePath),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
