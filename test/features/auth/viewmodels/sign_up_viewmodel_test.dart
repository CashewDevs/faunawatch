import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/auth/viewmodels/sign_up_viewmodel.dart';

class _FakeAuthService implements AuthService {
  bool shouldSucceed = true;

  @override
  Future<bool> login(String email, String password) async => shouldSucceed;

  @override
  Future<bool> signUp(String email, String password) async => shouldSucceed;
}

void main() {
  group('SignUpViewModel', () {
    test('initial state has empty credentials and sign up disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(signUpViewModelProvider);
      expect(state.email, '');
      expect(state.password, '');
      expect(state.confirmPassword, '');
      expect(state.isSignUpEnabled, false);
      expect(state.isPasswordVisible, false);
      expect(state.isConfirmPasswordVisible, false);
    });

    test('updating fields enables sign up when all are populated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(signUpViewModelProvider.notifier);
      notifier.onEmailChanged('scout@fauna.org');
      expect(container.read(signUpViewModelProvider).isSignUpEnabled, false);

      notifier.onPasswordChanged('password123');
      expect(container.read(signUpViewModelProvider).isSignUpEnabled, false);

      notifier.onConfirmPasswordChanged('password123');
      expect(container.read(signUpViewModelProvider).isSignUpEnabled, true);
    });

    test('toggling password visibilities flips flags', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(signUpViewModelProvider.notifier);
      expect(container.read(signUpViewModelProvider).isPasswordVisible, false);
      notifier.togglePasswordVisibility();
      expect(container.read(signUpViewModelProvider).isPasswordVisible, true);

      expect(
        container.read(signUpViewModelProvider).isConfirmPasswordVisible,
        false,
      );
      notifier.toggleConfirmPasswordVisibility();
      expect(
        container.read(signUpViewModelProvider).isConfirmPasswordVisible,
        true,
      );
    });

    test('submitSignUp succeeds with valid credentials', () async {
      final fakeAuth = _FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fakeAuth)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(signUpViewModelProvider.notifier);
      notifier.onEmailChanged('scout@fauna.org');
      notifier.onPasswordChanged('password123');
      notifier.onConfirmPasswordChanged('password123');

      final result = await notifier.submitSignUp();
      expect(result, true);
      expect(container.read(signUpViewModelProvider).isSubmitting, false);
    });
  });
}
