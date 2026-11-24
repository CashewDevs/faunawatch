import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/post_management/models/own_post_menu.dart';
import 'package:faunawatch/features/post_management/viewmodels/post_actions_viewmodel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';

enum _OwnPostOption { hide, unhide, delete }

/// Opens the "⋯" menu of one of the user's own posts and carries out the
/// choice: hide (with Undo), show again, or delete after a confirmation.
/// [onDeleted] runs after a successful delete, e.g. to close the screen.
///
/// The post's screen may go away while an action runs (a hidden post leaves
/// the feed), so the messenger and the ViewModel are read before any wait.
Future<void> showOwnPostOptions(
  BuildContext context,
  WidgetRef ref,
  OwnPostMenu menu, {
  VoidCallback? onDeleted,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final actions = ref.read(postActionsViewModelProvider.notifier);
  final choice = await showModalBottomSheet<_OwnPostOption>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OwnPostOptionsSheet(menu: menu),
  );
  if (choice == null) return;

  void show(String text, {SnackBarAction? action}) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));

  switch (choice) {
    case _OwnPostOption.hide:
      final result = await actions.setHidden(menu.postId, hidden: true);
      if (result.error case final error?) return show(error);
      if (!result.done) return;
      show(
        'Post hidden. Only you can see it, on your profile.',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final undo = await actions.setHidden(menu.postId, hidden: false);
            if (undo.error case final error?) show(error);
          },
        ),
      );
    case _OwnPostOption.unhide:
      final result = await actions.setHidden(menu.postId, hidden: false);
      if (result.error case final error?) return show(error);
      if (result.done) show('Post shown again.');
    case _OwnPostOption.delete:
      if (!context.mounted || !await _confirmDelete(context)) return;
      final result = await actions.delete(menu.postId);
      if (result.error case final error?) return show(error);
      if (!result.done) return;
      show('Post deleted.');
      onDeleted?.call();
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const dangerRed = Color(0xFFDC2626);
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      actionsPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkErrorBackground
                  : AppColors.consentBadgeRedBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? AppColors.darkErrorText : dangerRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete this post?',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'This can\'t be undone. Its photos, likes and comments are deleted '
        'too.',
        style: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: isDark ? AppColors.darkTextBody : const Color(0xFF475569),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF64748B),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerRed,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Delete',
            style: GoogleFonts.dmSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The choices for one own post. Pops with the chosen option.
class _OwnPostOptionsSheet extends StatelessWidget {
  const _OwnPostOptionsSheet({required this.menu});

  final OwnPostMenu menu;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1E293B);
    final hintColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF64748B);
    final accent = isDark
        ? AppPaletteColors.of(context).darkAccentBlue
        : AppPaletteColors.of(context).messagesHeaderBlue;
    final danger = isDark ? AppColors.darkErrorText : const Color(0xFFD32F2F);
    void choose(_OwnPostOption option) => Navigator.of(context).pop(option);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkIconMuted
                      : const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Text(
              'Your post',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFEDF2F7),
            ),
            const SizedBox(height: 10),
            if (menu.canHide)
              _OptionTile(
                icon: Icons.visibility_off_outlined,
                label: 'Hide post',
                hint: 'Only you and admins will see it.',
                iconColor: accent,
                textColor: textColor,
                hintColor: hintColor,
                onTap: () => choose(_OwnPostOption.hide),
              ),
            if (menu.canUnhide)
              _OptionTile(
                icon: Icons.visibility_outlined,
                label: 'Show post again',
                hint: menu.status == ReportStatus.approved
                    ? 'Everyone can see it again.'
                    : 'Everyone can see it once an admin approves it.',
                iconColor: accent,
                textColor: textColor,
                hintColor: hintColor,
                onTap: () => choose(_OwnPostOption.unhide),
              ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete post',
              hint: 'Removes it for good.',
              iconColor: danger,
              textColor: danger,
              hintColor: hintColor,
              onTap: () => choose(_OwnPostOption.delete),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.iconColor,
    required this.textColor,
    required this.hintColor,
    required this.onTap,
  });

  final IconData icon;
  final String label, hint;
  final Color iconColor, textColor, hintColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      hint,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
