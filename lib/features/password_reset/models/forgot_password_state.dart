/// Presentation state of the Forgot password screen.
class ForgotPasswordState {
  const ForgotPasswordState({
    this.email = '',
    this.isSending = false,
    this.sentTo,
    this.secondsUntilResend = 0,
    this.errorMessage,
  });

  /// Supabase sends one reset email per account per minute.
  static const int resendDelaySeconds = 60;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final String email;
  final bool isSending;

  /// The address the latest link went to; null until one is sent.
  final String? sentTo;

  /// Seconds left before "Send again" works; 0 when it does.
  final int secondsUntilResend;

  final String? errorMessage;

  /// Whether [email] looks like an email address (the server decides the
  /// rest).
  bool get isEmailValid => _emailPattern.hasMatch(email.trim());

  /// Whether the first link can be asked for.
  bool get canSend => isEmailValid && !isSending;

  /// Whether another link can be asked for after one was sent.
  bool get canResend => sentTo != null && secondsUntilResend == 0 && !isSending;

  ForgotPasswordState copyWith({
    String? email,
    bool? isSending,
    String? sentTo,
    bool clearSentTo = false,
    int? secondsUntilResend,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      isSending: isSending ?? this.isSending,
      sentTo: clearSentTo ? null : (sentTo ?? this.sentTo),
      secondsUntilResend: secondsUntilResend ?? this.secondsUntilResend,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
