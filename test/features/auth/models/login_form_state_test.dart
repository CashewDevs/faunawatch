import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/models/login_form_state.dart';

void main() {
  group('LoginFormState', () {
    test('initial state defaults to empty fields and disabled login', () {
      const state = LoginFormState();

      expect(state.email, '');
      expect(state.password, '');
      expect(state.isPasswordVisible, false);
      expect(state.isSubmitting, false);
      expect(state.errorMessage, isNull);
      expect(state.isLoginEnabled, false);
    });

    test('isLoginEnabled is false when only email is filled', () {
      const state = LoginFormState(email: 'user@example.com');
      expect(state.isLoginEnabled, false);
    });

    test('isLoginEnabled is false when only password is filled', () {
      const state = LoginFormState(password: 'secret');
      expect(state.isLoginEnabled, false);
    });

    test(
      'isLoginEnabled is true only when both email and password are provided',
      () {
        const state = LoginFormState(
          email: 'user@example.com',
          password: 'secret',
        );
        expect(state.isLoginEnabled, true);
      },
    );

    test('copyWith properly updates specified properties', () {
      const initial = LoginFormState();
      final updated = initial.copyWith(
        email: 'test@example.com',
        password: 'pass',
        isPasswordVisible: true,
        isSubmitting: true,
        errorMessage: 'Invalid credentials',
      );

      expect(updated.email, 'test@example.com');
      expect(updated.password, 'pass');
      expect(updated.isPasswordVisible, true);
      expect(updated.isSubmitting, true);
      expect(updated.errorMessage, 'Invalid credentials');
    });
  });
}
