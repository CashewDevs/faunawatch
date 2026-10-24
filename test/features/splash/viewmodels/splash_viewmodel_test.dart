import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/splash/viewmodels/splash_viewmodel.dart';

void main() {
  group('SplashViewModel', () {
    test('initial state is initializing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(splashViewModelProvider);
      expect(state, SplashState.initializing);
    });

    test('initializeApp transitions state to complete after delay', () async {
      final container = ProviderContainer();
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
