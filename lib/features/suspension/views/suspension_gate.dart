import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import 'package:faunawatch/features/suspension/views/suspended_view.dart';

/// Wraps the app's navigator (from `MaterialApp.builder`). While the user's
/// suspension is locked it shows [SuspendedView] instead, so no screen of
/// the app, pushed or not, can be reached.
///
/// The navigator is removed while locked; when the lock ends (or the user
/// signs out) it starts again from the splash screen, which sends the user
/// to the right place. Re-checks the suspension whenever the app resumes.
class SuspensionGate extends ConsumerStatefulWidget {
  const SuspensionGate({super.key, required this.child});

  final Widget? child;

  @override
  ConsumerState<SuspensionGate> createState() => _SuspensionGateState();
}

class _SuspensionGateState extends ConsumerState<SuspensionGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          ref.read(accountSuspensionViewModelProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suspension = ref.watch(accountSuspensionViewModelProvider);
    if (suspension != null && suspension.isLocked) {
      // Its own navigator gives the screen an overlay (snackbars, ink) and
      // leaves Back with nothing to go back to.
      return Navigator(
        key: const ValueKey('suspended_navigator'),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => SuspendedView(suspension: suspension),
        ),
      );
    }
    return widget.child ?? const SizedBox.shrink();
  }
}
