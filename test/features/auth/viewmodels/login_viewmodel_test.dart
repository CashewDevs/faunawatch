import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/auth/viewmodels/login_viewmodel.dart';

class _FakeAuthService implements AuthService {
  bool shouldSucceed = true;

  @override
  Future<bool> login(String email, String password) async {
    return shouldSucceed;
  }

  @override
  Future<bool> signUp(String email, String password) async {
    return shouldSucceed;
  }
}

void main() {
  group('LoginViewModel', () {
    test('initial state has empty credentials and login disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(loginViewModelProvider);
      expect(state.email, '');
      expect(state.password, '');
      expect(state.isLoginEnabled, false);
      expect(state.isPasswordVisible, false);
    });

    test(
      'onEmailChanged and onPasswordChanged update credentials and enable login',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(loginViewModelProvider.notifier)
            .onEmailChanged('user@test.com');
        expect(container.read(loginViewModelProvider).email, 'user@test.com');
        expect(container.read(loginViewModelProvider).isLoginEnabled, false);

        container
            .read(loginViewModelProvider.notifier)
            .onPasswordChanged('mypassword');
        expect(container.read(loginViewModelProvider).password, 'mypassword');
        expect(container.read(loginViewModelProvider).isLoginEnabled, true);
      },
    );

    test('togglePasswordVisibility flips isPasswordVisible flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginViewModelProvider.notifier);
      expect(container.read(loginViewModelProvider).isPasswordVisible, false);

      notifier.togglePasswordVisibility();
      expect(container.read(loginViewModelProvider).isPasswordVisible, true);

      notifier.togglePasswordVisibility();
      expect(container.read(loginViewModelProvider).isPasswordVisible, false);
    });

    test('submitLogin returns false when login is not enabled', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(loginViewModelProvider.notifier)
          .submitLogin();
      expect(result, false);
    });

    test('submitLogin succeeds when valid credentials provided', () async {
      final fakeAuth = _FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(loginViewModelProvider.notifier);
      notifier.onEmailChanged('user@test.com');
      notifier.onPasswordChanged('securepass');

      final result = await notifier.submitLogin();
      expect(result, true);
      expect(container.read(loginViewModelProvider).isSubmitting, false);
    });
  });
}
