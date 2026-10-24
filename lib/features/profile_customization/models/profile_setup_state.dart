/// Immutable state representing user input and status during initial profile customization.
class ProfileSetupState {
  const ProfileSetupState({
    this.username = '',
    this.bio = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String username;
  final String bio;
  final bool isSubmitting;
  final String? errorMessage;

  static const int maxUsernameLength = 20;
  static const int maxBioLength = 50;

  /// The continue button is pressable only when both username and bio are being typed on.
  bool get isContinueEnabled =>
      username.trim().isNotEmpty && bio.trim().isNotEmpty;

  ProfileSetupState copyWith({
    String? username,
    String? bio,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      username: username ?? this.username,
      bio: bio ?? this.bio,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
