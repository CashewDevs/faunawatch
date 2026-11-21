import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/profile/models/settings_state.dart';
import 'package:faunawatch/features/profile/services/profile_storage_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// ViewModel managing settings options, preferences, and session termination.
class SettingsViewModel extends Notifier<SettingsState> {
  late final ProfileStorageService _storageService;

  @override
  SettingsState build() {
    _storageService = ref.watch(profileStorageServiceProvider);
    // The push choice is stored per device and loaded by PushViewModel.
    ref.listen<bool>(pushViewModelProvider.select((push) => push.enabled), (
      _,
      enabled,
    ) {
      state = state.copyWith(pushNotificationsEnabled: enabled);
    });
    return SettingsState(
      pushNotificationsEnabled: ref.read(pushViewModelProvider).enabled,
    );
  }

  /// Sets the active palette ID for the "Change Theme" selection.
  void setPalette(String paletteId) {
    state = state.copyWith(activePaletteId: paletteId);
  }

  /// Toggles push notifications for this device: the choice is remembered and
  /// this device's token is registered (on) or unregistered (off).
  Future<void> togglePushNotifications(bool enabled) {
    state = state.copyWith(pushNotificationsEnabled: enabled);
    return ref.read(pushViewModelProvider.notifier).setEnabled(enabled);
  }

  /// Toggles location privacy.
  void toggleLocationPrivacy(bool enabled) {
    state = state.copyWith(locationPrivacyEnabled: enabled);
  }

  /// Signs the user out, resets shell navigation to default Feed, and invalidates session.
  Future<bool> signOut() async {
    // The push token is removed first, while the session can still call the
    // database.
    final push = ref.read(pushViewModelProvider.notifier);
    await push.onBeforeSignOut();
    final success = await _storageService.signOut();
    if (!success) await push.onSignOutFailed();
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
