import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

/// Confirmation dialog asking the user if they are sure they want to sign out.
class SignOutConfirmationDialog extends ConsumerWidget {
  const SignOutConfirmationDialog({super.key});

  Future<void> _handleConfirmSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(settingsViewModelProvider.notifier).signOut();

    if (context.mounted) {
      // Pop the dialog
      Navigator.of(context).pop();

      // Redirect to the very first screen, clearing navigation history
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.signOutButtonRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Sign Out',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to sign out? You will need to log back in to access your reports and messages.',
        style: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.signOutButtonRed,
            foregroundColor: AppColors.signOutTextYellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () => _handleConfirmSignOut(context, ref),
          child: Text(
            'Sign Out',
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
