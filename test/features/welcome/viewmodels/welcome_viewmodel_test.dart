import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/welcome/viewmodels/welcome_viewmodel.dart';

void main() {
  group('WelcomeViewModel', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(welcomeViewModelProvider);
      expect(state, WelcomeStatus.idle);
    });

    test('onLoginPressed sets status to navigatingToLogin', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(welcomeViewModelProvider.notifier).onLoginPressed();
      expect(
        container.read(welcomeViewModelProvider),
        WelcomeStatus.navigatingToLogin,
      );
    });

    test('onSignUpPressed sets status to navigatingToSignUp', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(welcomeViewModelProvider.notifier).onSignUpPressed();
      expect(
        container.read(welcomeViewModelProvider),
        WelcomeStatus.navigatingToSignUp,
      );
    });

    test('resetStatus resets status back to idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(welcomeViewModelProvider.notifier).onLoginPressed();
      expect(
        container.read(welcomeViewModelProvider),
        WelcomeStatus.navigatingToLogin,
      );

      container.read(welcomeViewModelProvider.notifier).resetStatus();
      expect(container.read(welcomeViewModelProvider), WelcomeStatus.idle);
    });
  });
}
