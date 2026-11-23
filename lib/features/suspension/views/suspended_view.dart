import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import 'package:faunawatch/features/suspension/views/widgets/suspension_notices.dart';

/// The only screen a locked user sees: why, until when, and Sign out.
/// It goes away by itself when the suspension ends or is lifted.
class SuspendedView extends ConsumerStatefulWidget {
  const SuspendedView({super.key, required this.suspension});

  final AccountSuspension suspension;

  @override
  ConsumerState<SuspendedView> createState() => _SuspendedViewState();
}

class _SuspendedViewState extends ConsumerState<SuspendedView> {
  bool _checking = false;
  bool _signingOut = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await ref.read(accountSuspensionViewModelProvider.notifier).refresh();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final signedOut = await ref
        .read(accountSuspensionViewModelProvider.notifier)
        .signOut();
    if (!mounted) return;
    setState(() => _signingOut = false);
    if (!signedOut) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The latest details; [widget.suspension] covers the last frame before
    // the lock is removed.
    final suspension =
        ref.watch(accountSuspensionViewModelProvider) ?? widget.suspension;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = _checking || _signingOut;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.block_rounded,
                        size: 48,
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account suspended',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suspension.endsAt == null
                        ? "You can't use FaunaWatch until an admin lifts "
                              'the suspension.'
                        : "You can't use FaunaWatch "
                              '${suspension.untilPhrase}. It unlocks by '
                              'itself when the suspension ends.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                      child: SuspensionDetails(suspension: suspension),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton(
                    key: const Key('suspended_check_again'),
                    onPressed: busy ? null : _checkAgain,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _checking ? 'Checking...' : 'Check again',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('suspended_sign_out'),
                    onPressed: busy ? null : _signOut,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      backgroundColor: AppColors.signOutButtonRed,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _signingOut ? 'Signing out...' : 'Sign out',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
