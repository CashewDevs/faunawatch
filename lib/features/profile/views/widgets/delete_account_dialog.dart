import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';
import 'package:faunawatch/features/account_deletion/viewmodels/account_deletion_viewmodel.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

/// Confirmation modal explaining what deleting the account does. The user
/// types "Delete" to enable the button; the account is then deleted after
/// [accountDeletionGraceDays] days unless they sign in and keep it.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  static const consequences = [
    'You are signed out on all your devices, and your saved AI keys are '
        'removed from this phone.',
    "For the next $accountDeletionGraceDays days, other people can't see "
        'your profile, posts, comments or chats.',
    'Changed your mind? Sign in within $accountDeletionGraceDays days and '
        'choose "Keep my account".',
    'After $accountDeletionGraceDays days, your profile, reports, photos, '
        'comments, chats and notifications are permanently deleted. This '
        "can't be undone.",
  ];

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _confirmation = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    // Both outlive this dialog.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    final AccountDeletionRequestResult result;
    try {
      result = await ref
          .read(accountDeletionViewModelProvider.notifier)
          .requestDeletion(_confirmation.text);
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error.failure.message;
      });
      return;
    }
    // Not signed out: the "Keep my account" screen has already taken over.
    if (!result.signedOut) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeView()),
      (route) => false,
    );
    messenger?.showSnackBar(
      SnackBar(
        key: const Key('account_deletion_scheduled_snackbar'),
        duration: const Duration(seconds: 8),
        content: Text(
          'Your account will be deleted on '
          '${result.deletion.deleteAfterLabel}. Sign in before then to '
          'keep it.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consequences = DeleteAccountDialog.consequences;
    final confirmed = isDeleteConfirmation(_confirmation.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final dangerBg = isDark
        ? const Color(0xFF991B1B).withValues(alpha: 0.22)
        : const Color(0xFFFEF2F2);
    final dangerBorder = isDark
        ? const Color(0xFF7F1D1D)
        : const Color(0xFFFECACA);
    final dangerAccent = isDark
        ? const Color(0xFFFCA5A5)
        : AppColors.signOutButtonRed;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.signOutButtonRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: dangerAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete account',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dangerBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dangerBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens next:',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dangerAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < consequences.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: dangerAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            consequences[i],
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              height: 1.4,
                              color: bodyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type $accountDeletionConfirmWord to confirm',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('delete_account_confirm_field'),
              controller: _confirmation,
              enabled: !_deleting,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              onChanged: (_) => setState(() => _error = null),
              style: GoogleFonts.dmSans(fontSize: 15, color: titleColor),
              decoration: InputDecoration(
                hintText: accountDeletionConfirmWord,
                errorText: _error,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        ElevatedButton(
          key: const ValueKey('delete_account_confirm_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.signOutButtonRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: confirmed && !_deleting ? _delete : null,
          child: Text(
            _deleting ? 'Deleting...' : 'Delete account',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
