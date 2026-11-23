import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/password_reset/models/forgot_password_state.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';

/// Forgot password screen: asks for a reset link, then counts down until
/// another one may be asked for.
class ForgotPasswordViewModel extends AutoDisposeNotifier<ForgotPasswordState> {
  Timer? _countdown;

  @override
  ForgotPasswordState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const ForgotPasswordState();
  }

  void setEmail(String value) {
    state = state.copyWith(email: value, clearError: true);
  }

  /// Emails the first link. False when nothing was sent.
  Future<bool> send() async {
    if (!state.canSend) return false;
    return _send(state.email.trim());
  }

  /// Emails a new link to the same address; the previous one stops working.
  Future<bool> sendAgain() async {
    if (!state.canResend) return false;
    return _send(state.sentTo!);
  }

  /// Goes back to the email field, e.g. to fix a typo.
  void changeEmail() {
    _countdown?.cancel();
    state = state.copyWith(
      clearSentTo: true,
      secondsUntilResend: 0,
      clearError: true,
    );
  }

  Future<bool> _send(String email) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      await ref.read(passwordResetServiceProvider).sendResetEmail(email);
    } catch (error) {
      state = state.copyWith(isSending: false, errorMessage: _message(error));
      return false;
    }
    state = state.copyWith(
      isSending: false,
      sentTo: email,
      secondsUntilResend: ForgotPasswordState.resendDelaySeconds,
    );
    _startCountdown();
    return true;
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.secondsUntilResend - 1;
      state = state.copyWith(secondsUntilResend: left < 0 ? 0 : left);
      if (left <= 0) timer.cancel();
    });
  }

  /// Supabase's own error text is never shown.
  static String _message(Object error) {
    if (error is AuthRetryableFetchException) {
      return "Can't reach FaunaWatch. Check your internet connection and "
          'try again.';
    }
    if (error is AuthException &&
        (error.statusCode == '429' ||
            error.code == 'over_email_send_rate_limit')) {
      return 'A reset link was sent a moment ago. Please wait a minute and '
          'try again.';
    }
    if (error is AuthException &&
        (error.code == 'email_address_invalid' ||
            error.code == 'validation_failed')) {
      return 'Enter a valid email address.';
    }
    return "We couldn't send the reset link. Please try again.";
  }
}

/// Auto-disposing provider exposing [ForgotPasswordViewModel].
final forgotPasswordViewModelProvider =
    AutoDisposeNotifierProvider<ForgotPasswordViewModel, ForgotPasswordState>(
      ForgotPasswordViewModel.new,
    );
