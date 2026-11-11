import 'package:faunawatch/features/auth/services/google_auth_service.dart';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import '../../auth/fake_google_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/splash/viewmodels/splash_viewmodel.dart';

void main() {
  for (final target in [AuthDestination.home, AuthDestination.profileSetup]) {
    test('restores $target on startup', () async {
      final service = FakeGoogleAuthService()..destination = target;
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [googleAuthServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      await container
          .read(splashViewModelProvider.notifier)
          .initializeApp(delay: Duration.zero);
      expect(
        container.read(splashViewModelProvider),
        target == AuthDestination.home
            ? SplashState.home
            : SplashState.profileSetup,
      );
    });
  }

  test('restoration failure can be retried', () async {
    final service = FakeGoogleAuthService()
      ..resolveError = StateError('offline');
    addTearDown(service.dispose);
    final container = ProviderContainer(
      overrides: [googleAuthServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final vm = container.read(splashViewModelProvider.notifier);
    await vm.initializeApp(delay: Duration.zero);
    expect(container.read(splashViewModelProvider), SplashState.failed);
    service.resolveError = null;
    await vm.initializeApp(delay: Duration.zero);
    expect(container.read(splashViewModelProvider), SplashState.complete);
  });

  group('SplashViewModel', () {
    test('initial state is initializing', () {
      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(FakeGoogleAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(splashViewModelProvider);
      expect(state, SplashState.initializing);
    });

    test('initializeApp transitions state to complete after delay', () async {
      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(FakeGoogleAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final future = container
          .read(splashViewModelProvider.notifier)
          .initializeApp(delay: const Duration(milliseconds: 10));

      expect(container.read(splashViewModelProvider), SplashState.initializing);
      await future;
      expect(container.read(splashViewModelProvider), SplashState.complete);
    });
  });
}
