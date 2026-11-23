import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';

/// What happened when a reset link opened the app.
enum ResetLinkEvent {
  /// Supabase signed the user in from the link; they may now choose a new
  /// password.
  opened,

  /// The link can't be used: already used, expired, replaced by a newer one,
  /// or opened on another phone.
  failed,
}

/// Forgot password through an emailed link that opens the app.
abstract interface class PasswordResetService {
  /// Emails a reset link that opens this app. Supabase answers the same way
  /// when no account uses [email], and then sends nothing.
  Future<void> sendResetEmail(String email);

  /// Reset links opened in this app. A new listener first receives the latest
  /// one, if it is still the latest auth event (the link may have started the
  /// app before anything was listening).
  Stream<ResetLinkEvent> get linkEvents;

  /// The signed-in account's email, if any.
  String? get currentEmail;

  /// Sets the signed-in account's password.
  Future<void> setNewPassword(String password);
}

/// Supabase-backed [PasswordResetService].
///
/// The link opens `com.faunawatch.app://login-callback/` (Android manifest,
/// iOS Info.plist; allowed in Supabase's redirect URLs). Before emailing,
/// Supabase's library keeps a secret on this phone marked "password recovery";
/// when the link comes back, it trades the link's code and that secret for a
/// session and reports [AuthChangeEvent.passwordRecovery] instead of
/// signedIn. That is why the link only works on the phone that asked.
class SupabasePasswordResetService implements PasswordResetService {
  const SupabasePasswordResetService(this._client);

  /// Must equal the address `supabase/templates/recovery.html` checks for,
  /// so the email sends the app's link through Supabase.
  static const redirectUrl = 'com.faunawatch.app://login-callback/';

  final SupabaseClient _client;

  @override
  Future<void> sendResetEmail(String email) =>
      _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);

  @override
  Stream<ResetLinkEvent> get linkEvents =>
      _client.auth.onAuthStateChange.transform(
        StreamTransformer<AuthState, ResetLinkEvent>.fromHandlers(
          handleData: (state, sink) {
            if (state.event == AuthChangeEvent.passwordRecovery) {
              sink.add(ResetLinkEvent.opened);
            }
          },
          // Other auth errors (e.g. a failed token refresh offline) are not
          // about a link and are left to their own screens.
          handleError: (error, stackTrace, sink) {
            if (isResetLinkError(error)) sink.add(ResetLinkEvent.failed);
          },
        ),
      );

  @override
  String? get currentEmail => _client.auth.currentUser?.email;

  @override
  Future<void> setNewPassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));
}

/// Supabase's codes for a link that can't be used, as reported when the app
/// opens it.
@visibleForTesting
const resetLinkErrorCodes = {
  // Supabase uses this one code for used, expired and replaced links; it
  // arrives in the link itself (`#error_code=otp_expired`).
  'otp_expired',
  // The code in the link was refused when traded for a session.
  'flow_state_expired',
  'flow_state_not_found',
  'bad_code_verifier',
};

/// Whether [error], reported on the auth stream, means a reset link that
/// opened the app can't be used.
@visibleForTesting
bool isResetLinkError(Object error) {
  if (error is! AuthException) return false;
  if (resetLinkErrorCodes.contains(error.statusCode) ||
      resetLinkErrorCodes.contains(error.code)) {
    return true;
  }
  // The secret kept on the phone is missing: the link was opened on another
  // phone, or the app was reinstalled since asking.
  return error.message.startsWith('Code verifier could not be found');
}

/// Riverpod provider exposing [PasswordResetService].
final passwordResetServiceProvider = Provider<PasswordResetService>((ref) {
  return SupabasePasswordResetService(ref.watch(supabaseClientProvider));
});
