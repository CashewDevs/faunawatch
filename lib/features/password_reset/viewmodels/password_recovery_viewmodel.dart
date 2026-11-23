import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/password_reset/models/password_recovery_state.dart';
import 'package:faunawatch/features/password_reset/services/password_reset_service.dart';

/// Follows reset links that open the app, for the whole time the app runs,
/// and drives the screens they lead to (see `PasswordRecoveryGate`).
///
/// Not auto-disposed on purpose: listening again later would receive the
/// latest link event a second time.
class PasswordRecoveryViewModel extends Notifier<PasswordRecoveryState> {
  @override
  PasswordRecoveryState build() {
    final service = ref.watch(passwordResetServiceProvider);
    final subscription = service.linkEvents.listen(_onLinkEvent);
    ref.onDispose(subscription.cancel);
    return const PasswordRecoveryState();
  }

  void _onLinkEvent(ResetLinkEvent event) {
    // A password being saved or a sign-out under way finishes first.
    if (state.isBusy) return;
    state = switch (event) {
      ResetLinkEvent.opened => PasswordRecoveryState(
        stage: RecoveryStage.choosing,
        email: ref.read(passwordResetServiceProvider).currentEmail,
      ),
      ResetLinkEvent.failed => const PasswordRecoveryState(
        stage: RecoveryStage.linkFailed,
      ),
    };
  }

  void setNewPassword(String value) {
    state = state.copyWith(newPassword: value, clearError: true);
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value, clearError: true);
  }

  void toggleObscureNew() {
    state = state.copyWith(obscureNew: !state.obscureNew);
  }

  void toggleObscureConfirm() {
    state = state.copyWith(obscureConfirm: !state.obscureConfirm);
  }

  /// Saves the new password; the user stays signed in.
  Future<void> save() async {
    if (state.stage != RecoveryStage.choosing || !state.canSave) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await ref
          .read(passwordResetServiceProvider)
          .setNewPassword(state.newPassword);
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _saveError(error));
      return;
    }
    state = PasswordRecoveryState(
      stage: RecoveryStage.saved,
      email: state.email,
    );
  }

  /// Leaves without a new password. The link signed the user in, so this
  /// signs them out: an abandoned reset leaves nobody signed in.
  Future<void> cancel() async {
    if (state.stage != RecoveryStage.choosing || state.isBusy) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            "Couldn't log you out. Check your internet connection and try "
            'again.',
      );
      return;
    }
    state = const PasswordRecoveryState();
  }

  /// Closes the "password updated" or "link can't be used" screen.
  void finish() {
    if (state.stage == RecoveryStage.saved ||
        state.stage == RecoveryStage.linkFailed) {
      state = const PasswordRecoveryState();
    }
  }

  /// Supabase's own error text is never shown.
  static String _saveError(Object error) {
    if (error is AuthRetryableFetchException) {
      return "Can't reach FaunaWatch. Check your internet connection and "
          'try again.';
    }
    if (error is AuthSessionMissingException) {
      return 'This reset has ended. Ask for a new link from the login '
          'screen.';
    }
    if (error is AuthException && error.code == 'same_password') {
      return "That's your current password. Choose a different one.";
    }
    if (error is AuthException && error.code == 'weak_password') {
      return 'That password is too easy to guess. Choose a stronger one.';
    }
    return "We couldn't save your new password. Please try again.";
  }
}

/// Provider exposing [PasswordRecoveryViewModel] for the app's lifetime.
final passwordRecoveryViewModelProvider =
    NotifierProvider<PasswordRecoveryViewModel, PasswordRecoveryState>(
      PasswordRecoveryViewModel.new,
    );
