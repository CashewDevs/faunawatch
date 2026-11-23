import 'package:faunawatch/data/models/password_rules.dart';

/// Where a reset link that opened the app has got to.
enum RecoveryStage {
  /// No reset link in progress; the app shows its normal screens.
  idle,

  /// A link signed the user in; they are choosing a new password.
  choosing,

  /// The new password is saved.
  saved,

  /// The link can't be used.
  linkFailed,
}

/// Presentation state of the screens a reset link opens.
class PasswordRecoveryState {
  const PasswordRecoveryState({
    this.stage = RecoveryStage.idle,
    this.email,
    this.newPassword = '',
    this.confirmPassword = '',
    this.obscureNew = true,
    this.obscureConfirm = true,
    this.isBusy = false,
    this.errorMessage,
  });

  final RecoveryStage stage;

  /// The account the link signed in to, shown so the user knows which one.
  final String? email;

  final String newPassword;
  final String confirmPassword;
  final bool obscureNew;
  final bool obscureConfirm;

  /// Saving the password or cancelling (signing out) is under way.
  final bool isBusy;

  final String? errorMessage;

  bool get hasMinLength => PasswordRules.hasMinLength(newPassword);

  bool get hasLetterAndNumber => PasswordRules.hasLetterAndNumber(newPassword);

  bool get matchesConfirmation =>
      newPassword.isNotEmpty && newPassword == confirmPassword;

  /// Whether Save can be pressed.
  bool get canSave =>
      hasMinLength && hasLetterAndNumber && matchesConfirmation && !isBusy;

  PasswordRecoveryState copyWith({
    String? newPassword,
    String? confirmPassword,
    bool? obscureNew,
    bool? obscureConfirm,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PasswordRecoveryState(
      stage: stage,
      email: email,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscureNew: obscureNew ?? this.obscureNew,
      obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
