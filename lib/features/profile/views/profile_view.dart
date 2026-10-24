import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/edit_profile_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_action_card.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_header_card.dart';
import 'package:faunawatch/features/profile/views/widgets/theme_picker_sheet.dart';

/// Screen displaying the user's profile with chosen banner, avatar, username, bio,
/// and interactive buttons for Edit Profile, Change Theme, and Settings.
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
    final profile = ref.watch(profileViewModelProvider);
    final settings = ref.watch(settingsViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.3, 1.0],
          colors: isDark
              ? const [
                  AppColors.darkProfileGradientStart,
                  AppColors.darkProfileGradientEnd,
                ]
              : const [
                  AppColors.profileBackgroundGradientStart,
                  AppColors.profileBackgroundGradientEnd,
                ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Topmost user chosen set: banner goes to top edge!
            ProfileHeaderCard(profile: profile),

            const SizedBox(height: 6),

            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'PROFILE & PREFERENCES',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Button 1: Edit Profile
            ProfileActionCard(
              icon: Icons.person_outline_rounded,
              iconBackgroundColor: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Edit Profile',
              subtitle: 'Update username, bio, avatar & banner',
              onTap: () => _openEditProfile(context),
            ),

            // Button 2: Change Theme
            ProfileActionCard(
              icon: Icons.palette_outlined,
              iconBackgroundColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: 'Change Theme',
              subtitle: 'Customize accent color palette',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.activePaletteId.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ],
                ),
              ),
              onTap: () => _openThemePicker(context),
            ),

            // Button 3: Settings
            ProfileActionCard(
              icon: Icons.settings_outlined,
              iconBackgroundColor: const Color(0xFFCCFBF1),
              iconColor: const Color(0xFF0D9488),
              title: 'Settings',
              subtitle: 'Dark / Light mode, preferences & account',
              onTap: () => _openSettings(context),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
