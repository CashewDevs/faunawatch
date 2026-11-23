import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/data/models/password_rules.dart';
import 'package:faunawatch/features/profile/models/change_password_state.dart';

void main() {
  test('at least 8 characters', () {
    expect(PasswordRules.minLength, 8);
    expect(PasswordRules.hasMinLength('abc1234'), isFalse);
    expect(PasswordRules.hasMinLength('abcd1234'), isTrue);
  });

  test('a letter and a number', () {
    expect(PasswordRules.hasLetterAndNumber('abcdefgh'), isFalse);
    expect(PasswordRules.hasLetterAndNumber('12345678'), isFalse);
    expect(PasswordRules.hasLetterAndNumber('abcd1234'), isTrue);
    expect(PasswordRules.hasLetterAndNumber('1234ABCD'), isTrue);
  });

  test('Change Password uses the same rules', () {
    expect(ChangePasswordState.minPasswordLength, PasswordRules.minLength);
    const weak = ChangePasswordState(newPassword: 'abcdefgh');
    const strong = ChangePasswordState(newPassword: 'abcd1234');
    expect(weak.hasMinLength, isTrue);
    expect(weak.hasLetterAndNumber, isFalse);
    expect(strong.hasLetterAndNumber, isTrue);
  });
}
