import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/password_reset/models/password_recovery_state.dart';
import 'package:faunawatch/features/password_reset/viewmodels/password_recovery_viewmodel.dart';
import 'package:faunawatch/features/password_reset/views/screens/choose_password_view.dart';
import 'package:faunawatch/features/password_reset/views/screens/password_updated_view.dart';
import 'package:faunawatch/features/password_reset/views/screens/reset_link_failed_view.dart';

/// Wraps the app's navigator (from `MaterialApp.builder`). When a reset link
/// opens the app, it shows "Choose a new password" instead of every other
/// screen, then "Password updated" or "This link can't be used".
///
/// Like `SuspensionGate`, the navigator is removed meanwhile; afterwards it
/// starts again from the splash screen, which sends the user to the right
/// place (home after saving, Welcome after cancelling).
class PasswordRecoveryGate extends ConsumerWidget {
  const PasswordRecoveryGate({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      passwordRecoveryViewModelProvider.select((state) => state.stage),
    );
    if (stage == RecoveryStage.idle) {
      return child ?? const SizedBox.shrink();
    }
    // Its own navigator gives the screens an overlay (text selection, ink)
    // and leaves Back with nothing to go back to.
    return Navigator(
      key: ValueKey('password_recovery_$stage'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => switch (stage) {
          RecoveryStage.saved => const PasswordUpdatedView(),
          RecoveryStage.linkFailed => const ResetLinkFailedView(),
          _ => const ChoosePasswordView(),
        },
      ),
    );
  }
}
