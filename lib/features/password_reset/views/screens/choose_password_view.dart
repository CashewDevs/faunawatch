import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/data/models/password_rules.dart';
import 'package:faunawatch/features/auth/views/widgets/auth_text_field.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/password_reset/viewmodels/password_recovery_viewmodel.dart';
import 'package:faunawatch/features/password_reset/views/widgets/password_reset_frame.dart';
import 'package:faunawatch/features/password_reset/views/widgets/password_fields.dart';

/// "Choose a new password", after a reset link signed the user in.
class ChoosePasswordView extends ConsumerWidget {
  const ChoosePasswordView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(passwordRecoveryViewModelProvider);
    final viewModel = ref.read(passwordRecoveryViewModelProvider.notifier);
    final email = state.email;

    return PasswordResetFrame(
      title: 'Choose a new\npassword',
      subtitle: email == null
          ? 'Pick a password you will remember.'
          : 'For $email. Pick a password you will remember.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.errorMessage != null) ...[
            PasswordResetMessage(message: state.errorMessage!),
            const SizedBox(height: 18),
          ],
          AuthTextField(
            label: 'New Password',
            prefixIconPath: AppAssets.passwordIcon,
            obscureText: state.obscureNew,
            textInputAction: TextInputAction.next,
            onChanged: viewModel.setNewPassword,
            suffixIcon: PasswordVisibilityButton(
              isVisible: !state.obscureNew,
              onPressed: viewModel.toggleObscureNew,
            ),
          ),
          const SizedBox(height: 18),
          AuthTextField(
            label: 'Confirm New Password',
            prefixIconPath: AppAssets.passwordIcon,
            obscureText: state.obscureConfirm,
            textInputAction: TextInputAction.done,
            onChanged: viewModel.setConfirmPassword,
            suffixIcon: PasswordVisibilityButton(
              isVisible: !state.obscureConfirm,
              onPressed: viewModel.toggleObscureConfirm,
            ),
          ),
          const SizedBox(height: 18),
          PasswordRequirement(
            label: 'At least ${PasswordRules.minLength} characters',
            met: state.hasMinLength,
          ),
          const SizedBox(height: 8),
          PasswordRequirement(
            label: 'Includes a letter and a number',
            met: state.hasLetterAndNumber,
          ),
          const SizedBox(height: 8),
          PasswordRequirement(
            label: 'Both passwords match',
            met: state.matchesConfirmation,
          ),
          const SizedBox(height: 32),
          LoginActionButton(
            label: 'Save Password',
            isEnabled: state.canSave,
            isLoading: state.isBusy,
            onPressed: viewModel.save,
          ),
          const SizedBox(height: 12),
          PasswordResetLinkButton(
            label: 'Cancel and log out',
            onPressed: state.isBusy ? null : viewModel.cancel,
          ),
        ],
      ),
    );
  }
}
