import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';

void main() {
  test('a used, expired or replaced link (error in the link itself)', () {
    // What the library builds from `#error=access_denied&error_code=otp_expired`.
    expect(
      isResetLinkError(
        AuthException(
          'Email link is invalid or has expired',
          statusCode: 'otp_expired',
          code: 'access_denied',
        ),
      ),
      isTrue,
    );
  });

  test('a code refused when traded for a session', () {
    for (final code in [
      'flow_state_expired',
      'flow_state_not_found',
      'bad_code_verifier',
    ]) {
      expect(
        isResetLinkError(AuthApiException('x', statusCode: '400', code: code)),
        isTrue,
        reason: code,
      );
    }
  });

  test('a link opened on another phone (no secret kept here)', () {
    expect(
      isResetLinkError(
        AuthException('Code verifier could not be found in local storage.'),
      ),
      isTrue,
    );
  });

  test('other auth errors are not about a link', () {
    expect(isResetLinkError(AuthRetryableFetchException()), isFalse);
    expect(
      isResetLinkError(
        AuthException(
          'Access denied',
          statusCode: '400',
          code: 'access_denied',
        ),
      ),
      isFalse,
    );
    expect(isResetLinkError(StateError('x')), isFalse);
  });

  test('the app link matches the reset email template', () {
    // recovery.html sends this exact address through Supabase (which opens
    // the app); any other address would get a link the app can't open.
    final template = File(
      'supabase/templates/recovery.html',
    ).readAsStringSync();
    expect(
      template,
      contains('ne .RedirectTo "${SupabasePasswordResetService.redirectUrl}"'),
    );
    expect(
      SupabasePasswordResetService.redirectUrl,
      'com.faunawatch.app://login-callback/',
    );
  });
}
