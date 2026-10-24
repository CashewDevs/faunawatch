import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/profile/models/settings_state.dart';
import 'package:faunawatch/features/profile/services/profile_storage_service.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// ViewModel managing settings options, preferences, and session termination.
class SettingsViewModel extends Notifier<SettingsState> {
  late final ProfileStorageService _storageService;

  @override
  SettingsState build() {
    _storageService = ref.watch(profileStorageServiceProvider);
    return const SettingsState();
  }

  /// Sets the active palette ID for the "Change Theme" selection.
  void setPalette(String paletteId) {
    state = state.copyWith(activePaletteId: paletteId);
  }

  /// Toggles push notifications.
  void togglePushNotifications(bool enabled) {
    state = state.copyWith(pushNotificationsEnabled: enabled);
  }

  /// Toggles location privacy.
  void toggleLocationPrivacy(bool enabled) {
    state = state.copyWith(locationPrivacyEnabled: enabled);
  }

  /// Signs the user out, resets shell navigation to default Feed, and invalidates session.
  Future<bool> signOut() async {
    final success = await _storageService.signOut();
    if (success) {
      ref
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.feed);
    }
    return success;
  }
}

/// Riverpod provider exposing [SettingsViewModel].
final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsState>(SettingsViewModel.new);
