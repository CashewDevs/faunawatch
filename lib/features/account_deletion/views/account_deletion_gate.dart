import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/account_deletion/viewmodels/account_deletion_viewmodel.dart';
import 'package:faunawatch/features/account_deletion/views/scheduled_deletion_view.dart';

/// Wraps the app (from `MaterialApp.builder`). While the signed-in account
/// is waiting to be deleted it shows [ScheduledDeletionView] instead, so no
/// other screen can be reached until the user keeps the account or signs
/// out.
///
/// Like the suspension lock, the app's navigator starts again from the
/// splash screen afterwards. Re-checks whenever the app resumes.
class AccountDeletionGate extends ConsumerStatefulWidget {
  const AccountDeletionGate({super.key, required this.child});

  final Widget? child;

  @override
  ConsumerState<AccountDeletionGate> createState() =>
      _AccountDeletionGateState();
}

class _AccountDeletionGateState extends ConsumerState<AccountDeletionGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(accountDeletionViewModelProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deletion = ref.watch(accountDeletionViewModelProvider);
    if (deletion != null) {
      // Its own navigator gives the screen an overlay (snackbars, ink) and
      // leaves Back with nothing to go back to.
      return Navigator(
        key: const ValueKey('scheduled_deletion_navigator'),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ScheduledDeletionView(deletion: deletion),
        ),
      );
    }
    return widget.child ?? const SizedBox.shrink();
  }
}
