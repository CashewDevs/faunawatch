import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/auth/models/auth_destination.dart';
import 'package:faunawatch/features/auth/viewmodels/google_sign_in_viewmodel.dart';
import 'package:faunawatch/features/auth/views/widgets/google_sign_in_button.dart';
import 'package:faunawatch/features/profile_customization/views/profile_setup_view.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

/// Shared Google action for login and registration. Navigation waits for a
/// confirmed session, never just a successful browser launch.
class GoogleAuthAction extends ConsumerWidget {
  const GoogleAuthAction({this.enabled = true, super.key});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(googleSignInViewModelProvider);
    ref.listen(googleSignInViewModelProvider, (previous, next) {
      final destination = next.destination;
      if (destination == null ||
          destination == previous?.destination ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => destination == AuthDestination.profileSetup
              ? const ProfileSetupView()
              : const ShellView(),
        ),
        (_) => false,
      );
    });
    final viewModel = ref.read(googleSignInViewModelProvider.notifier);
    return Column(
      children: [
        GoogleSignInButton(
          onPressed: enabled && !state.isBusy ? viewModel.signIn : null,
          isLoading: state.isBusy,
        ),
        if (state.isBusy) ...[
          const SizedBox(height: 8),
          const Text('Finish signing in with Google in your browser.'),
          TextButton(onPressed: viewModel.cancel, child: const Text('Cancel')),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(
            state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
