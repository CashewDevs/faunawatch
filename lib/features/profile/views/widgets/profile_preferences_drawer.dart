import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_action_card.dart';

/// Profile actions live behind the banner's hamburger menu, leaving the page
/// available for the user's bio and gallery.
class ProfilePreferencesDrawer extends ConsumerWidget {
  const ProfilePreferencesDrawer({
    super.key,
    required this.onEditProfile,
    required this.onChangeTheme,
    required this.onSettings,
  });

  final VoidCallback onEditProfile, onChangeTheme, onSettings;

  void _select(BuildContext context, VoidCallback action) {
    Scaffold.of(context).closeEndDrawer();
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paletteId = ref.watch(
      settingsViewModelProvider.select((settings) => settings.activePaletteId),
    );
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile & preferences',
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close profile menu',
                    onPressed: () => Scaffold.of(context).closeEndDrawer(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  ProfileActionCard(
                    icon: Icons.person_outline_rounded,
                    iconBackgroundColor: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Edit Profile',
                    subtitle: 'Update username, bio, avatar & banner',
                    onTap: () => _select(context, onEditProfile),
                  ),
                  ProfileActionCard(
                    icon: Icons.palette_outlined,
                    iconBackgroundColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Change Theme',
                    subtitle: 'Accent palette: ${paletteId.toUpperCase()}',
                    onTap: () => _select(context, onChangeTheme),
                  ),
                  ProfileActionCard(
                    icon: Icons.settings_outlined,
                    iconBackgroundColor: const Color(0xFFCCFBF1),
                    iconColor: const Color(0xFF0D9488),
                    title: 'Settings',
                    subtitle: 'Appearance, AI keys, preferences & account',
                    onTap: () => _select(context, onSettings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
