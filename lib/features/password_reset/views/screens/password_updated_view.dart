import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/password_reset/viewmodels/password_recovery_viewmodel.dart';
import 'package:faunawatch/features/password_reset/views/widgets/password_reset_frame.dart';

/// "Password updated", after saving.
class PasswordUpdatedView extends ConsumerWidget {
  const PasswordUpdatedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PasswordResetFrame(
      title: 'Password\nupdated',
      subtitle: 'You are logged in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PasswordResetText(
            'Use your new password the next time you log in, on this phone '
            'or any other.',
          ),
          const SizedBox(height: 32),
          LoginActionButton(
            label: 'Continue',
            isEnabled: true,
            onPressed: ref
                .read(passwordRecoveryViewModelProvider.notifier)
                .finish,
          ),
        ],
      ),
    );
  }
}
