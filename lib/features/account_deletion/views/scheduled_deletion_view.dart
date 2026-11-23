import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/viewmodels/account_deletion_viewmodel.dart';

/// Shown after signing in while the account is waiting to be deleted:
/// when it will be deleted, "Keep my account" and "Sign out".
///
/// Once the date has passed the account can't be kept, so only
/// "Sign out" is offered.
class ScheduledDeletionView extends ConsumerStatefulWidget {
  const ScheduledDeletionView({super.key, required this.deletion});

  final AccountDeletion deletion;

  @override
  ConsumerState<ScheduledDeletionView> createState() =>
      _ScheduledDeletionViewState();
}

class _ScheduledDeletionViewState extends ConsumerState<ScheduledDeletionView> {
  bool _keeping = false;
  bool _signingOut = false;
  bool _tooLate = false;

  Future<void> _keep() async {
    // The app's messenger outlives this screen, which closes on success.
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _keeping = true);
    try {
      await ref.read(accountDeletionViewModelProvider.notifier).keepAccount();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      setState(() {
        _keeping = false;
        _tooLate = error.failure == AccountDeletionFailure.tooLate;
      });
      messenger?.showSnackBar(SnackBar(content: Text(error.failure.message)));
      return;
    }
    messenger?.showSnackBar(
      const SnackBar(
        key: Key('account_restored_snackbar'),
        content: Text('Welcome back! Your account is restored.'),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final signedOut = await ref
        .read(accountDeletionViewModelProvider.notifier)
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
    final deletion =
        ref.watch(accountDeletionViewModelProvider) ?? widget.deletion;
    final due =
        _tooLate ||
        ref.read(accountDeletionViewModelProvider.notifier).isDue(deletion);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = _keeping || _signingOut;

    final title = due
        ? 'Your account is being deleted'
        : 'Your account will be deleted';
    final body = due
        ? 'The $accountDeletionGraceDays days have passed, so your account '
              "can't be kept. It will be gone shortly."
        : 'It will be deleted on ${deletion.deleteAfterLabel}. Until then, '
              "other people can't see your profile, posts, comments or "
              'chats.\n\nChanged your mind? Keep your account and '
              'everything comes back.';

    final buttonText = GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

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
                        due
                            ? Icons.delete_forever_rounded
                            : Icons.hourglass_bottom_rounded,
                        size: 46,
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    key: const Key('scheduled_deletion_body'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!due) ...[
                    FilledButton(
                      key: const Key('scheduled_deletion_keep'),
                      onPressed: busy ? null : _keep,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _keeping ? 'Keeping...' : 'Keep my account',
                        style: buttonText,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton(
                    key: const Key('scheduled_deletion_sign_out'),
                    onPressed: busy ? null : _signOut,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _signingOut ? 'Signing out...' : 'Sign out',
                      style: buttonText,
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
