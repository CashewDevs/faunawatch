import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/features/profile/models/change_password_state.dart';
import 'package:faunawatch/features/profile/services/password_service.dart';

/// ViewModel managing Change Password form state, validation, and submission.
class ChangePasswordViewModel extends AutoDisposeNotifier<ChangePasswordState> {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  void setCurrentPassword(String value) {
    state = state.copyWith(
      currentPassword: value,
      clearError: true,
      clearInfo: true,
    );
  }

  void setNewPassword(String value) {
    state = state.copyWith(
      newPassword: value,
      clearError: true,
      clearInfo: true,
    );
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(
      confirmPassword: value,
      clearError: true,
      clearInfo: true,
    );
  }

  void toggleObscureCurrent() {
    state = state.copyWith(obscureCurrent: !state.obscureCurrent);
  }

  void toggleObscureNew() {
    state = state.copyWith(obscureNew: !state.obscureNew);
  }

  void toggleObscureConfirm() {
    state = state.copyWith(obscureConfirm: !state.obscureConfirm);
  }

  /// Validates and submits the password change via [PasswordService].
  Future<bool> submit() async {
    if (state.isSubmitting) return false;

    if (state.currentPassword.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter your current password.',
        clearInfo: true,
      );
      return false;
    }
    if (!state.hasMinLength) {
      state = state.copyWith(
        errorMessage:
            'New password must be at least ${ChangePasswordState.minPasswordLength} characters.',
        clearInfo: true,
      );
      return false;
    }
    if (!state.hasLetterAndNumber) {
      state = state.copyWith(
        errorMessage: 'New password must include a letter and a number.',
        clearInfo: true,
      );
      return false;
    }
    if (!state.matchesConfirmation) {
      state = state.copyWith(
        errorMessage: 'New password and confirmation do not match.',
        clearInfo: true,
      );
      return false;
    }
    if (state.newPassword == state.currentPassword) {
      state = state.copyWith(
        errorMessage:
            'New password must be different from your current password.',
        clearInfo: true,
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    try {
      await ref
          .read(passwordServiceProvider)
          .changePassword(
            currentPassword: state.currentPassword,
            newPassword: state.newPassword,
          );
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message.isNotEmpty
            ? e.message
            : 'Unable to update password. Please try again.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Unable to update password. Please try again.',
      );
      return false;
    }
  }

  /// Sends a password reset link to the current user's email address.
  Future<bool> sendResetEmail() async {
    if (state.isSendingReset) return false;
    state = state.copyWith(
      isSendingReset: true,
      clearError: true,
      clearInfo: true,
    );
    try {
      final email = await ref
          .read(passwordServiceProvider)
          .sendPasswordResetEmail();
      state = state.copyWith(
        isSendingReset: false,
        infoMessage: 'Password reset link sent to $email.',
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isSendingReset: false,
        errorMessage: e.message.isNotEmpty
            ? e.message
            : 'Unable to send password reset email.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSendingReset: false,
        errorMessage: 'Unable to send password reset email. Please try again.',
      );
      return false;
    }
  }
}

/// Auto-disposing provider exposing [ChangePasswordViewModel].
final changePasswordViewModelProvider =
    AutoDisposeNotifierProvider<ChangePasswordViewModel, ChangePasswordState>(
      ChangePasswordViewModel.new,
    );
