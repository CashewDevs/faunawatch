import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/auth/views/widgets/auth_text_field.dart';
import 'package:faunawatch/features/auth/views/widgets/login_action_button.dart';
import 'package:faunawatch/features/password_reset/models/forgot_password_state.dart';
import 'package:faunawatch/features/password_reset/viewmodels/forgot_password_viewmodel.dart';
import 'package:faunawatch/features/password_reset/views/widgets/password_reset_frame.dart';

/// Opened from the Login screen's "Forgot Password?": asks for the account's
/// email and sends a reset link that opens the app.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key, this.initialEmail = ''});

  /// What was already typed on the Login screen, if anything.
  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );

  @override
  void initState() {
    super.initState();
    if (_email.text.isNotEmpty) {
      // After the first frame: a provider can't change while building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(forgotPasswordViewModelProvider.notifier)
              .setEmail(_email.text);
        }
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordViewModelProvider);
    final viewModel = ref.read(forgotPasswordViewModelProvider.notifier);
    final sentTo = state.sentTo;

    return PasswordResetFrame(
      title: sentTo == null ? 'Forgot\nPassword?' : 'Check your\nemail',
      subtitle: sentTo == null
          ? "Enter your account's email and we'll send you a link to choose "
                'a new password.'
          : 'Open the link on this phone to choose a new password.',
      onBack: () => Navigator.of(context).maybePop(),
      child: sentTo == null
          ? _EmailForm(
              state: state,
              controller: _email,
              onChanged: viewModel.setEmail,
              onSend: viewModel.send,
            )
          : _SentNotice(
              state: state,
              sentTo: sentTo,
              onSendAgain: viewModel.sendAgain,
              onChangeEmail: viewModel.changeEmail,
              onBackToLogin: () => Navigator.of(context).maybePop(),
            ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    required this.state,
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  final ForgotPasswordState state;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null) ...[
          PasswordResetMessage(message: state.errorMessage!),
          const SizedBox(height: 18),
        ],
        AuthTextField(
          label: 'Email Address',
          prefixIconPath: AppAssets.usernameIcon,
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
        ),
        const SizedBox(height: 32),
        LoginActionButton(
          label: 'Send Reset Link',
          isEnabled: state.canSend,
          isLoading: state.isSending,
          onPressed: onSend,
        ),
      ],
    );
  }
}

class _SentNotice extends StatelessWidget {
  const _SentNotice({
    required this.state,
    required this.sentTo,
    required this.onSendAgain,
    required this.onChangeEmail,
    required this.onBackToLogin,
  });

  final ForgotPasswordState state;
  final String sentTo;
  final VoidCallback onSendAgain;
  final VoidCallback onChangeEmail;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final wait = state.secondsUntilResend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null) ...[
          PasswordResetMessage(message: state.errorMessage!),
          const SizedBox(height: 18),
        ],
        PasswordResetText(
          'If an account uses $sentTo, we sent it a reset link. '
          "If you don't see it, check your spam folder.",
        ),
        const SizedBox(height: 14),
        const PasswordResetMessage(
          isError: false,
          message:
              'Open the link on this phone. It works once, for 1 hour, and '
              'only the newest link works.',
        ),
        const SizedBox(height: 32),
        LoginActionButton(
          label: wait > 0 ? 'Send Again in ${wait}s' : 'Send Again',
          isEnabled: state.canResend,
          isLoading: state.isSending,
          onPressed: onSendAgain,
        ),
        const SizedBox(height: 12),
        PasswordResetLinkButton(
          label: 'Use a different email',
          onPressed: state.isSending ? null : onChangeEmail,
        ),
        PasswordResetLinkButton(
          label: 'Back to Log In',
          onPressed: onBackToLogin,
        ),
      ],
    );
  }
}
