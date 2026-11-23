import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/password_reset/viewmodels/password_recovery_viewmodel.dart';
import 'package:faunawatch/features/password_reset/views/widgets/password_reset_frame.dart';

/// "This link can't be used", for a used, expired or replaced link, or one
/// opened on another phone.
class ResetLinkFailedView extends ConsumerWidget {
  const ResetLinkFailedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PasswordResetFrame(
      title: "This link can't\nbe used",
      subtitle: 'Your password has not changed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PasswordResetText(
            'A reset link works once and for 1 hour, and asking for a new '
            'one cancels the old one. It also only works on the phone where '
            'you asked for it.',
          ),
          const SizedBox(height: 14),
          const PasswordResetText(
            'To try again, tap "Forgot Password?" on the Log In screen.',
          ),
          const SizedBox(height: 32),
          LoginActionButton(
            label: 'OK',
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
