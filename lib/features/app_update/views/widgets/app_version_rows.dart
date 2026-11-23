import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/app_update/models/app_release.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
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
    final latest = ref.read(appUpdateViewModelProvider).latest;
    if (latest != null) await showUpdateAvailableDialog(context, latest);
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

/// Tells the user a newer version is out, with its release notes, and offers
/// its download page.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  AppRelease release,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final installed = ref.watch(appUpdateViewModelProvider).installed;
        final bodyStyle = GoogleFonts.dmSans(fontSize: 14, height: 1.4);
        return AlertDialog(
          title: Text(
            'Update available',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Version ${release.version.label} is ready.'
                    '${installed == null ? '' : ' You have ${installed.label}.'}',
                    style: bodyStyle,
                  ),
                  if (release.notes != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      "What's new",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(release.notes!, style: bodyStyle),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(dialogContext);
                final opened = await ref
                    .read(appUpdateViewModelProvider.notifier)
                    .openReleasePage();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!opened) {
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text("Couldn't open the download page."),
                    ),
                  );
                }
              },
              child: const Text('Open download page'),
            ),
          ],
        );
      },
    ),
  );
}
