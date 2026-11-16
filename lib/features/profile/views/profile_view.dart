import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_preferences_drawer.dart';
import 'package:faunawatch/features/profile/views/widgets/theme_picker_sheet.dart';

/// Profile content and gallery, with preferences behind a hamburger menu.
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  void _openEditProfile(BuildContext context) {
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

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsView()));
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
      endDrawer: ProfilePreferencesDrawer(
        onEditProfile: () => _openEditProfile(context),
        onChangeTheme: () => _openThemePicker(context),
        onSettings: () => _openSettings(context),
      ),
      body: Builder(
        // Capture this Scaffold, rather than the gallery's nested Scaffold.
        builder: (menuContext) => Container(
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
                      AppPaletteColors.of(
                        context,
                      ).profileBackgroundGradientStart,
                      AppPaletteColors.of(context).profileBackgroundGradientEnd,
                    ],
            ),
          ),
          child: GalleryView(
            header: ProfileHeaderCard(
              profile: profile,
              onOpenMenu: () => Scaffold.of(menuContext).openEndDrawer(),
            ),
          ),
        ),
      ),
    );
  }
}
