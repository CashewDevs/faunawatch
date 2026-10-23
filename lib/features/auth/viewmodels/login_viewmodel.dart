import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/models/login_form_state.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// ViewModel managing presentation state and actions for the Login screen.
class LoginViewModel extends Notifier<LoginFormState> {
  late final AuthService _authService;

  @override
  LoginFormState build() {
    _authService = ref.watch(authServiceProvider);
    return const LoginFormState();
  }

  /// Updates the email / username in state.
  void onEmailChanged(String email) {
    state = state.copyWith(email: email);
  }

  /// Updates the password in state.
  void onPasswordChanged(String password) {
    state = state.copyWith(password: password);
  }

  /// Toggles visibility of the password field.
  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  /// Submits the login form via [AuthService].
  Future<bool> submitLogin() async {
    if (!state.isLoginEnabled || state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final success = await _authService.login(state.email, state.password);
      state = state.copyWith(isSubmitting: false);
      return success;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Login failed. Please check your credentials.',
      );
      return false;
    }
  }
}

/// Provider exposing [LoginViewModel] and its [LoginFormState].
final loginViewModelProvider = NotifierProvider<LoginViewModel, LoginFormState>(
  LoginViewModel.new,
);
