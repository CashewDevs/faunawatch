/// Immutable presentation state for the user settings screen.
///
/// The Privacy section's "Private posts" switch has its own state
/// (PostsPrivacyState), because it is saved to the account, not the phone.
class SettingsState {
  const SettingsState({
    this.pushNotificationsEnabled = true,
    this.activePaletteId = 'apollo',
  });

  final bool pushNotificationsEnabled;
  final String activePaletteId;

  SettingsState copyWith({
    bool? pushNotificationsEnabled,
    String? activePaletteId,
  }) {
    return SettingsState(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      activePaletteId: activePaletteId ?? this.activePaletteId,
    );
  }
}
