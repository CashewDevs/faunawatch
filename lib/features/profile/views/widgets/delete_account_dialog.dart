import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Confirmation modal explaining the consequences of deleting an account.
///
/// Presentation-only UI with no account-deletion backend action wired yet.
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  static const _consequences = [
    'Your profile, username, bio, and avatar will be permanently removed and cannot be recovered.',
    'Your submitted wildlife reports, comments, and uploaded photos will no longer be linked to an active account.',
    'Your private chats, notification history, and saved AI API keys on this device will be cleared.',
    'This action is permanent and cannot be undone.',
  ];

  @override
  Widget build(BuildContext context) {
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
              'Are you sure you want to delete this account?',
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
                    'What happens if you delete your account:',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dangerAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _consequences.length; i++) ...[
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
                            _consequences[i],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Delete account',
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
