import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';

/// When the signed-in user is suspended, shows why [action] isn't possible
/// and returns true, so the caller stops. Returns false otherwise.
///
/// The database refuses these actions anyway; this explains it up front
/// instead of a generic "couldn't save" error.
bool blockedBySuspension(
  BuildContext context,
  WidgetRef ref,
  SuspendedAction action,
) {
  final suspension = ref.read(accountSuspensionViewModelProvider);
  if (suspension == null) return false;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(suspension.blockedMessage(action)),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            if (context.mounted) {
              SuspensionDetailsSheet.show(context, suspension);
            }
          },
        ),
      ),
    );
  return true;
}

/// Takes the place of a comment or message input bar while suspended.
class SuspendedInputNote extends StatelessWidget {
  const SuspendedInputNote({
    super.key,
    required this.suspension,
    required this.action,
  });

  final AccountSuspension suspension;
  final SuspendedAction action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('suspended_input_note'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => SuspensionDetailsSheet.show(context, suspension),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: colors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suspension.blockedMessage(action),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A restricted user's card at the top of the Feed. Takes no space when the
/// user isn't suspended. (A locked user sees only the suspension screen.)
class SuspensionBanner extends ConsumerWidget {
  const SuspensionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspension = ref.watch(accountSuspensionViewModelProvider);
    if (suspension == null || suspension.isLocked) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('suspension_banner'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => SuspensionDetailsSheet.show(context, suspension),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_maybe_rounded, color: colors.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your account is suspended',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "You can browse, but you can't post, comment, like, "
                        'message or edit your profile '
                        '${suspension.untilPhrase}.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          height: 1.35,
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onErrorContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reason, the admin's message and the end of a suspension.
class SuspensionDetails extends StatelessWidget {
  const SuspensionDetails({super.key, required this.suspension});

  final AccountSuspension suspension;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final end = suspension.endsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailRow(label: 'Reason', value: suspension.reasonLabel),
        if (suspension.message.isNotEmpty)
          _DetailRow(
            label: 'Message from the FaunaWatch team',
            value: suspension.message,
          ),
        _DetailRow(
          label: 'Ends',
          value: end == null
              ? 'When an admin lifts the suspension'
              : formatSuspensionDate(end),
        ),
        _DetailRow(
          label: 'Started',
          value: formatSuspensionDate(suspension.startedAt),
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 15.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: color ?? colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with [SuspensionDetails] for a restricted user.
class SuspensionDetailsSheet extends StatelessWidget {
  const SuspensionDetailsSheet({super.key, required this.suspension});

  final AccountSuspension suspension;

  static Future<void> show(
    BuildContext context,
    AccountSuspension suspension,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SuspensionDetailsSheet(suspension: suspension),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your account is suspended',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You can still browse FaunaWatch, but you can't post reports, "
              'comment, like, send messages or edit your profile until it '
              'ends.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SuspensionDetails(suspension: suspension),
          ],
        ),
      ),
    );
  }
}
