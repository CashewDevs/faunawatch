import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/password_reset/models/forgot_password_state.dart';
import 'package:faunawatch/features/password_reset/models/password_recovery_state.dart';

void main() {
  group('ForgotPasswordState', () {
    test('needs something that looks like an email', () {
      for (final email in ['', 'spotter', 'spotter@', 'a b@c.d', '@x.com']) {
        expect(
          ForgotPasswordState(email: email).canSend,
          isFalse,
          reason: email,
        );
      }
      expect(
        const ForgotPasswordState(email: ' spotter@example.com ').canSend,
        isTrue,
      );
      expect(
        const ForgotPasswordState(
          email: 'spotter@example.com',
          isSending: true,
        ).canSend,
        isFalse,
      );
    });

    test('send again only after a link was sent and the wait is over', () {
      expect(const ForgotPasswordState().canResend, isFalse);
      expect(
        const ForgotPasswordState(
          sentTo: 'a@b.co',
          secondsUntilResend: 12,
        ).canResend,
        isFalse,
      );
      expect(const ForgotPasswordState(sentTo: 'a@b.co').canResend, isTrue);
    });

    test('copyWith can clear the address and the error', () {
      const state = ForgotPasswordState(sentTo: 'a@b.co', errorMessage: 'x');
      final cleared = state.copyWith(clearSentTo: true, clearError: true);
      expect(cleared.sentTo, isNull);
      expect(cleared.errorMessage, isNull);
    });
  });

  group('PasswordRecoveryState', () {
    test('save needs every rule met and nothing under way', () {
      const base = PasswordRecoveryState(stage: RecoveryStage.choosing);
      expect(base.canSave, isFalse);
      expect(
        base
            .copyWith(newPassword: 'abcd1234', confirmPassword: 'abcd1234')
            .canSave,
        isTrue,
      );
      expect(
        base
            .copyWith(newPassword: 'abcdefgh', confirmPassword: 'abcdefgh')
            .canSave,
        isFalse,
      );
      expect(
        base
            .copyWith(newPassword: 'abcd1234', confirmPassword: 'abcd12345')
            .canSave,
        isFalse,
      );
      expect(
        base
            .copyWith(
              newPassword: 'abcd1234',
              confirmPassword: 'abcd1234',
              isBusy: true,
            )
            .canSave,
        isFalse,
      );
    });

    test('copyWith keeps the stage and the email', () {
      const state = PasswordRecoveryState(
        stage: RecoveryStage.choosing,
        email: 'a@b.co',
      );
      final next = state.copyWith(newPassword: 'x');
      expect(next.stage, RecoveryStage.choosing);
      expect(next.email, 'a@b.co');
    });
  });
}
