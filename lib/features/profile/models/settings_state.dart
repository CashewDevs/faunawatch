/// Immutable presentation state for the user settings screen.
class SettingsState {
  const SettingsState({
    this.pushNotificationsEnabled = true,
    this.locationPrivacyEnabled = true,
    this.activePaletteId = 'forest',
  });

  final bool pushNotificationsEnabled;
  final bool locationPrivacyEnabled;
  final String activePaletteId;

  SettingsState copyWith({
    bool? pushNotificationsEnabled,
    bool? locationPrivacyEnabled,
    String? activePaletteId,
  }) {
    return SettingsState(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      locationPrivacyEnabled:
          locationPrivacyEnabled ?? this.locationPrivacyEnabled,
      activePaletteId: activePaletteId ?? this.activePaletteId,
    );
  }
}
