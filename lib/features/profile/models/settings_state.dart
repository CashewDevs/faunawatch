/// Immutable presentation state for the user settings screen.
class SettingsState {
  const SettingsState({
    this.pushNotificationsEnabled = true,
    this.locationPrivacyEnabled = true,
    bool hideNameOnReports = false,
    this.activePaletteId = 'apollo',
  }) : _hideNameOnReports = hideNameOnReports;

  final bool pushNotificationsEnabled;
  final bool locationPrivacyEnabled;
  final bool? _hideNameOnReports;
  final String activePaletteId;

  /// Defaults to `false` even if an existing instance is hot-reloaded.
  bool get hideNameOnReports => _hideNameOnReports ?? false;

  SettingsState copyWith({
    bool? pushNotificationsEnabled,
    bool? locationPrivacyEnabled,
    bool? hideNameOnReports,
    String? activePaletteId,
  }) {
    return SettingsState(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      locationPrivacyEnabled:
          locationPrivacyEnabled ?? this.locationPrivacyEnabled,
      hideNameOnReports: hideNameOnReports ?? this.hideNameOnReports,
      activePaletteId: activePaletteId ?? this.activePaletteId,
    );
  }
}
