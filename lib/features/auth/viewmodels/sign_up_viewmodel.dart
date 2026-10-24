import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/models/sign_up_form_state.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// ViewModel managing presentation state and actions for the Sign Up screen.
class SignUpViewModel extends Notifier<SignUpFormState> {
  late final AuthService _authService;

  @override
  SignUpFormState build() {
    _authService = ref.watch(authServiceProvider);
    return const SignUpFormState();
  }

  /// Updates the email in state.
  void onEmailChanged(String email) {
    state = state.copyWith(email: email, errorMessage: null);
  }

  /// Updates the password in state.
  void onPasswordChanged(String password) {
    state = state.copyWith(password: password, errorMessage: null);
  }

  /// Updates the confirm password in state.
  void onConfirmPasswordChanged(String confirmPassword) {
    state = state.copyWith(
      confirmPassword: confirmPassword,
      errorMessage: null,
    );
  }

  /// Toggles visibility of the password field.
  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  /// Toggles visibility of the confirm password field.
  void toggleConfirmPasswordVisibility() {
    state = state.copyWith(
      isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
    );
  }

  /// Submits the registration form via [AuthService].
  Future<bool> submitSignUp() async {
    if (!state.isSignUpEnabled || state.isSubmitting) {
      return false;
    }

    if (state.password != state.confirmPassword) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Passwords do not match.',
      );
      return false;
    }

    if (state.password.length < 6) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Password should be at least 6 characters.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final success = await _authService.signUp(state.email, state.password);
      state = state.copyWith(isSubmitting: false);
      return success;
    } on AuthException catch (e) {
      // Surface the real Supabase error (e.g. "User already registered",
      // "Password should be at least 6 characters", etc.)
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Registration failed. Please try again.',
      );
      return false;
    }
  }
}

/// Provider exposing [SignUpViewModel] and its [SignUpFormState].
final signUpViewModelProvider =
    NotifierProvider<SignUpViewModel, SignUpFormState>(SignUpViewModel.new);
