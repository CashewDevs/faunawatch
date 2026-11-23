import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/password_reset/models/forgot_password_state.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';
import 'package:faunawatch/features/password_reset/viewmodels/forgot_password_viewmodel.dart';
import '../fake_password_reset_service.dart';

void main() {
  late FakePasswordResetService service;
  late ProviderContainer container;

  ForgotPasswordState read() => container.read(forgotPasswordViewModelProvider);
  ForgotPasswordViewModel vm() =>
      container.read(forgotPasswordViewModelProvider.notifier);

  setUp(() {
    service = FakePasswordResetService();
    container = ProviderContainer(
      overrides: [passwordResetServiceProvider.overrideWithValue(service)],
    );
    container.listen(forgotPasswordViewModelProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test('sends to the trimmed address and starts the wait', () async {
    vm().setEmail('  spotter@example.com ');
    expect(await vm().send(), isTrue);

    expect(service.sentTo, ['spotter@example.com']);
    expect(read().sentTo, 'spotter@example.com');
    expect(read().secondsUntilResend, ForgotPasswordState.resendDelaySeconds);
    expect(read().canResend, isFalse);
  });

  test('nothing is sent for an address that does not look valid', () async {
    vm().setEmail('spotter');
    expect(await vm().send(), isFalse);
    expect(service.sentTo, isEmpty);
  });

  test('send again waits for the countdown', () async {
    vm().setEmail('spotter@example.com');
    await vm().send();
    expect(await vm().sendAgain(), isFalse);
    expect(service.sentTo, hasLength(1));
  });

  test('a different email goes back to the form', () async {
    vm().setEmail('spotter@example.com');
    await vm().send();
    vm().changeEmail();
    expect(read().sentTo, isNull);
    expect(read().secondsUntilResend, 0);
    expect(read().email, 'spotter@example.com');
  });

  final errors = <String, Object>{
    "Can't reach FaunaWatch. Check your internet connection and try again.":
        AuthRetryableFetchException(),
    'A reset link was sent a moment ago. Please wait a minute and try again.':
        const AuthApiException(
          'For security purposes, you can only request this after 42 seconds.',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
    'Enter a valid email address.': const AuthApiException(
      'Unable to validate email address: invalid format',
      statusCode: '400',
      code: 'validation_failed',
    ),
    "We couldn't send the reset link. Please try again.": StateError(
      'secret server detail',
    ),
  };
  errors.forEach((message, error) {
    test('shows a safe message for $error', () async {
      service.sendError = error;
      vm().setEmail('spotter@example.com');
      expect(await vm().send(), isFalse);
      expect(read().errorMessage, message);
      expect(read().sentTo, isNull);
      expect(read().isSending, isFalse);

      vm().setEmail('spotter@example.com');
      expect(read().errorMessage, isNull);
    });
  });
}
