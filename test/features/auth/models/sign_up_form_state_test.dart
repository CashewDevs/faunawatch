import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/auth/models/sign_up_form_state.dart';

void main() {
  group('SignUpFormState', () {
    test('initial state defaults to empty fields and disabled sign up', () {
      const state = SignUpFormState();

      expect(state.email, '');
      expect(state.password, '');
      expect(state.confirmPassword, '');
      expect(state.isPasswordVisible, false);
      expect(state.isConfirmPasswordVisible, false);
      expect(state.isSubmitting, false);
      expect(state.errorMessage, isNull);
      expect(state.isSignUpEnabled, false);
    });

    test('isSignUpEnabled is false when not all fields are filled', () {
      const state1 = SignUpFormState(email: 'user@test.com');
      expect(state1.isSignUpEnabled, false);

      const state2 = SignUpFormState(
        email: 'user@test.com',
        password: 'password123',
      );
      expect(state2.isSignUpEnabled, false);
    });

    test(
      'isSignUpEnabled is true when email, password, and confirm password are filled',
      () {
        const state = SignUpFormState(
          email: 'user@test.com',
          password: 'password123',
          confirmPassword: 'password123',
        );
        expect(state.isSignUpEnabled, true);
      },
    );

    test('copyWith properly updates properties', () {
      const initial = SignUpFormState();
      final updated = initial.copyWith(
        email: 'new@test.com',
        password: 'pass',
        confirmPassword: 'pass',
        isPasswordVisible: true,
        isConfirmPasswordVisible: true,
        isSubmitting: true,
        errorMessage: 'Error',
      );

      expect(updated.email, 'new@test.com');
      expect(updated.password, 'pass');
      expect(updated.confirmPassword, 'pass');
      expect(updated.isPasswordVisible, true);
      expect(updated.isConfirmPasswordVisible, true);
      expect(updated.isSubmitting, true);
      expect(updated.errorMessage, 'Error');
    });
  });
}
