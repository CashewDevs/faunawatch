import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

void main() {
  group('SettingsViewModel', () {
    test('initial state has default preferences', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(settingsViewModelProvider);
      expect(state.pushNotificationsEnabled, isTrue);
      expect(state.locationPrivacyEnabled, isTrue);
      expect(state.activePaletteId, 'forest');
    });

    test('setPalette updates active theme palette ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsViewModelProvider.notifier);
      notifier.setPalette('ocean');

      expect(
        container.read(settingsViewModelProvider).activePaletteId,
        'ocean',
      );
    });

    test('toggles preferences correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsViewModelProvider.notifier);
      notifier.togglePushNotifications(false);
      notifier.toggleLocationPrivacy(false);

      final state = container.read(settingsViewModelProvider);
      expect(state.pushNotificationsEnabled, isFalse);
      expect(state.locationPrivacyEnabled, isFalse);
    });

    test('signOut resets shell destination to feed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.profile);
      expect(container.read(shellViewModelProvider), ShellDestination.profile);

      final result = await container
          .read(settingsViewModelProvider.notifier)
          .signOut();
      expect(result, isTrue);
      expect(container.read(shellViewModelProvider), ShellDestination.feed);
    });
  });
}
