import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

/// Counts sign-outs; can fail like a sign-out that left the user signed in.
class _FakeAuth implements AuthService {
  _FakeAuth({this.fails = false});
  final bool fails;
  int signOutCalls = 0;

  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<bool> signUp(String email, String password) async => true;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (fails) throw StateError('still signed in');
  }
}

void main() {
  group('SettingsViewModel', () {
    test('initial state has default preferences', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(settingsViewModelProvider);
      expect(state.pushNotificationsEnabled, isTrue);
      expect(state.activePaletteId, 'apollo');
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

      final state = container.read(settingsViewModelProvider);
      expect(state.pushNotificationsEnabled, isFalse);
    });

    ProviderContainer withAuth(_FakeAuth auth) {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.profile);
      return container;
    }

    test('signOut ends the session and resets the shell to feed', () async {
      final auth = _FakeAuth();
      final container = withAuth(auth);
      expect(container.read(shellViewModelProvider), ShellDestination.profile);

      final result = await container
          .read(settingsViewModelProvider.notifier)
          .signOut();

      expect(result, isTrue);
      expect(auth.signOutCalls, 1);
      expect(container.read(shellViewModelProvider), ShellDestination.feed);
    });

    test('a failed signOut says so and keeps the shell', () async {
      final auth = _FakeAuth(fails: true);
      final container = withAuth(auth);

      final result = await container
          .read(settingsViewModelProvider.notifier)
          .signOut();

      expect(result, isFalse);
      expect(auth.signOutCalls, 1);
      expect(container.read(shellViewModelProvider), ShellDestination.profile);
    });
  });
}
