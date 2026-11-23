import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_preferences_drawer.dart';
import 'package:faunawatch/features/profile/views/widgets/sign_out_dialog.dart';
import 'package:faunawatch/features/profile/views/widgets/theme_picker_sheet.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_tag_sheet.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/views/widgets/suspension_notices.dart';

/// Profile content and gallery, with preferences behind a hamburger menu.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  void _openEditProfile(BuildContext context, WidgetRef ref) {
    if (blockedBySuspension(context, ref, SuspendedAction.editProfile)) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditProfileView()));
  }

  void _openThemePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ThemePickerSheet(),
    );
  }

  void _openProfileTags(BuildContext context, WidgetRef ref) {
    if (blockedBySuspension(context, ref, SuspendedAction.editProfile)) return;
    ProfileTagSheet.show(context);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsView()));
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const SignOutConfirmationDialog(),
    );
  }

  /// Opens the profile sidebar on the root navigator so it layers above the
  /// shell's bottom navigation bar.
  void _openProfileMenu(BuildContext context, WidgetRef ref) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) => Align(
        alignment: Alignment.centerRight,
        child: ProfilePreferencesDrawer(
          onClose: () => Navigator.of(dialogContext).pop(),
          onEditProfile: () => _openEditProfile(context, ref),
          onChangeTheme: () => _openThemePicker(context),
          onSettings: () => _openSettings(context),
          onSignOut: () => _showSignOutDialog(context),
        ),
      ),
      transitionBuilder: (_, animation, _, child) {
        if (reduceMotion) return child;
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: slide, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    // The shell reports the floating nav bar's height through this inset.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (profileState.isLoading) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (profileState.hasError) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load your profile.'),
              TextButton(
                onPressed: () => ref.invalidate(profileViewModelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final profile = profileState.requireValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.3, 1.0],
            colors: isDark
                ? [
                    AppPaletteColors.of(context).darkProfileGradientStart,
                    AppPaletteColors.of(context).darkProfileGradientEnd,
                  ]
                : [
                    AppPaletteColors.of(context).profileBackgroundGradientStart,
                    AppPaletteColors.of(context).profileBackgroundGradientEnd,
                  ],
          ),
        ),
        child: GalleryView(
          header: ProfileHeaderCard(
            profile: profile,
            onOpenMenu: () => _openProfileMenu(context, ref),
            onManageTag: () => _openProfileTags(context, ref),
          ),
        ),
      ),
    );
  }
}
