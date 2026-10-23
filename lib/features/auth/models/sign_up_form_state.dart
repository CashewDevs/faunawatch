/// Immutable state representing the user's input and status on the Sign Up screen.
class SignUpFormState {
  const SignUpFormState({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String email;
  final String password;
  final String confirmPassword;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final bool isSubmitting;
  final String? errorMessage;

  /// The Sign Up button is pressable when email, password, and confirm password are filled.
  bool get isSignUpEnabled =>
      email.trim().isNotEmpty &&
      password.isNotEmpty &&
      confirmPassword.isNotEmpty;

  SignUpFormState copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return SignUpFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
