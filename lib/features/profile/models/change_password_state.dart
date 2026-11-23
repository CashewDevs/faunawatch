import 'package:faunawatch/data/models/password_rules.dart';

/// Immutable presentation state for the Change Password screen.
class ChangePasswordState {
  const ChangePasswordState({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureCurrent = true,
    this.obscureNew = true,
    this.obscureConfirm = true,
    this.isSubmitting = false,
    this.isSendingReset = false,
    this.errorMessage,
    this.infoMessage,
  });

  static const int minPasswordLength = PasswordRules.minLength;

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
  final bool obscureCurrent;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool isSubmitting;
  final bool isSendingReset;
  final String? errorMessage;
  final String? infoMessage;

  /// Whether the new password meets the minimum character length.
  bool get hasMinLength => PasswordRules.hasMinLength(newPassword);

  /// Whether the new password contains at least one letter and one number.
  bool get hasLetterAndNumber => PasswordRules.hasLetterAndNumber(newPassword);

  /// Whether the confirmation matches the non-empty new password.
  bool get matchesConfirmation =>
      newPassword.isNotEmpty && newPassword == confirmPassword;

  /// Whether all password strength and confirmation checks pass.
  bool get allRequirementsMet =>
      hasMinLength && hasLetterAndNumber && matchesConfirmation;

  /// Whether the form is ready to submit.
  bool get canSubmit =>
      currentPassword.isNotEmpty && allRequirementsMet && !isSubmitting;

  ChangePasswordState copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    bool? obscureCurrent,
    bool? obscureNew,
    bool? obscureConfirm,
    bool? isSubmitting,
    bool? isSendingReset,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) {
    return ChangePasswordState(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureCurrent: obscureCurrent ?? this.obscureCurrent,
      obscureNew: obscureNew ?? this.obscureNew,
      obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSendingReset: isSendingReset ?? this.isSendingReset,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}
