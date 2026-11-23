import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/app_update/viewmodels/app_update_viewmodel.dart';
import 'package:faunawatch/features/app_update/views/widgets/update_available_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// "FaunaWatch 1.0.0 (5) is ready — Update | ✕" at the top of the Feed.
///
/// Starts the quiet automatic update check when first shown, and takes no
/// space while there is nothing to offer.
class AppUpdateBanner extends ConsumerStatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  ConsumerState<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends ConsumerState<AppUpdateBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(appUpdateViewModelProvider.notifier).autoCheck();
    });
  }

  Future<void> _update() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final viewModel = ref.read(appUpdateViewModelProvider.notifier);
    final ready = await viewModel.loadNewerRelease();
    if (!mounted) return;
    if (ready) {
      await showUpdateAvailableDialog(context);
      return;
    }
    final upToDate =
        ref.read(appUpdateViewModelProvider).status ==
        UpdateCheckStatus.upToDate;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          upToDate
              ? "FaunaWatch is up to date."
              : "Couldn't check for updates. Try again from Settings.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateViewModelProvider);
    final notice = state.notice;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppPaletteColors.of(context).shellHeaderBlue;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: notice == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Material(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE3F0FE),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  child: Row(
                    children: [
                      Icon(Icons.system_update_outlined, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'FaunaWatch ${notice.label} is ready',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (state.isChecking)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _update,
                          style: TextButton.styleFrom(foregroundColor: accent),
                          child: Text(
                            'Update',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Hide update notice',
                        onPressed: ref
                            .read(appUpdateViewModelProvider.notifier)
                            .dismissNotice,
                        icon: Icon(Icons.close_rounded, color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
