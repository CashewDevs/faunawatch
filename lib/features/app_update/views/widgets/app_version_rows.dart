import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:faunawatch/features/app_update/views/widgets/update_available_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "FaunaWatch Version" row and, on Android, "Check for updates", shown
/// at the bottom of Settings › About and Support.
class AppVersionRows extends ConsumerWidget {
  const AppVersionRows({super.key});

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    final viewModel = ref.read(appUpdateViewModelProvider.notifier);
    final before = ref.read(appUpdateViewModelProvider);
    // A known newer release opens straight away; otherwise check first.
    if (before.status != UpdateCheckStatus.available) {
      await viewModel.checkForUpdates();
    }
    if (!context.mounted) return;
    if (ref.read(appUpdateViewModelProvider).latest != null) {
      await showUpdateAvailableDialog(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FaunaWatch Version',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              if (state.installed != null)
                Text(
                  state.installed!.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        if (state.canCheck) ...[
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          InkWell(
            onTap: state.isChecking ? null : () => _check(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0E7A5F).withValues(alpha: 0.22)
                          : const Color(0xFFD9F5EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.system_update_outlined,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF0E7A5F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Check for updates',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusText(state),
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight:
                                state.status == UpdateCheckStatus.available
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: state.status == UpdateCheckStatus.available
                                ? (isDark
                                      ? AppColors.darkAccentBlue
                                      : const Color(0xFF1A5DC9))
                                : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.isChecking)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _statusText(AppUpdateState state) {
    if (state.isDownloading) {
      final progress = state.downloadProgress;
      return progress == null
          ? 'Downloading…'
          : 'Downloading… ${(progress * 100).floor()}%';
    }
    return switch (state.status) {
      UpdateCheckStatus.idle => 'See if a newer version is out',
      UpdateCheckStatus.checking => 'Checking…',
      UpdateCheckStatus.upToDate => "You're up to date",
      UpdateCheckStatus.available =>
        'Version ${state.latest?.version.label ?? ''} is ready',
      UpdateCheckStatus.failed => "Couldn't check. Tap to try again.",
    };
  }
}
