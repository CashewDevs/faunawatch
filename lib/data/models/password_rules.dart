/// FaunaWatch's rules for a new password. Shared by Change Password and the
/// screen a reset link opens, so both ask for the same thing.
abstract final class PasswordRules {
  /// The shortest password accepted.
  static const int minLength = 8;

  static final RegExp _letter = RegExp(r'[A-Za-z]');
  static final RegExp _number = RegExp(r'[0-9]');

  /// Whether [password] is at least [minLength] characters long.
  static bool hasMinLength(String password) => password.length >= minLength;

  /// Whether [password] contains at least one letter and one number.
  static bool hasLetterAndNumber(String password) =>
      _letter.hasMatch(password) && _number.hasMatch(password);
}
