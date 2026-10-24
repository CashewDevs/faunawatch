/// Immutable state representing the user's input and status on the Login screen.
class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isPasswordVisible;
  final bool isSubmitting;
  final String? errorMessage;

  /// The Log In button is only pressable when both email/username and password are filled.
  bool get isLoginEnabled => email.trim().isNotEmpty && password.isNotEmpty;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
