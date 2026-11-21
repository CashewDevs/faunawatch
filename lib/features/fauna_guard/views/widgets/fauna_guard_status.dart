import 'package:flutter/material.dart';
import '../../models/fauna_guard_state.dart';

class FaunaGuardStatus extends StatelessWidget {
  const FaunaGuardStatus({
    super.key,
    required this.state,
    required this.onDismissAlert,
    required this.onDismissMessage,
    required this.onSettings,
  });
  final FaunaGuardState state;
  final VoidCallback onDismissAlert, onDismissMessage, onSettings;

  @override
  Widget build(BuildContext context) {
    if (!state.isEnabled && state.message == null) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              state.message == null ? Icons.shield : Icons.info_outline,
              color: colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.message != null
                        ? 'FaunaGuard is off'
                        : state.alertTitle ??
                              (state.status == GuardStatus.starting
                                  ? 'Starting FaunaGuard…'
                                  : 'FaunaGuard is on'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.message ??
                        state.alertBody ??
                        (state.status == GuardStatus.starting
                            ? 'Waiting for location and permissions.'
                            : 'Watching nearby reports, including while locked.'),
                  ),
                  if (state.message != null)
                    TextButton(
                      onPressed: onSettings,
                      child: const Text('App settings'),
                    ),
                ],
              ),
            ),
            if (state.message != null || state.alert != null)
              IconButton(
                tooltip: 'Dismiss FaunaGuard message',
                onPressed: state.message != null
                    ? onDismissMessage
                    : onDismissAlert,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
