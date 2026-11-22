import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/profile_action_card.dart';
import 'package:faunawatch/features/profile/views/widgets/theme_mode_card.dart';

/// Profile actions live behind the banner's hamburger menu, leaving the page
/// available for the user's bio and gallery.
class ProfilePreferencesDrawer extends ConsumerWidget {
  const ProfilePreferencesDrawer({
    super.key,
    required this.onEditProfile,
    required this.onChangeTheme,
    required this.onSettings,
    required this.onSignOut,
    this.onClose,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onChangeTheme;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final VoidCallback? onClose;

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _select(BuildContext context, VoidCallback action) {
    _close(context);
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppPaletteColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final paletteId = ref.watch(
      settingsViewModelProvider.select((settings) => settings.activePaletteId),
    );
    return Drawer(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
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
                    onPressed: () => _close(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                const ThemeModeCard(),
                ProfileActionCard(
                  icon: Icons.person_outline_rounded,
                  iconBackgroundColor: colors.resolve(
                    const Color(0xFFE0F2FE),
                    scheme.primaryContainer,
                  ),
                  iconColor: colors.resolve(
                    const Color(0xFF0284C7),
                    scheme.primary,
                  ),
                  title: 'Edit Profile',
                  subtitle: 'Update username, bio, avatar & banner',
                  onTap: () => _select(context, onEditProfile),
                ),
                ProfileActionCard(
                  icon: Icons.palette_outlined,
                  iconBackgroundColor: colors.resolve(
                    const Color(0xFFFEF3C7),
                    scheme.primaryContainer,
                  ),
                  iconColor: colors.resolve(
                    const Color(0xFFD97706),
                    scheme.primary,
                  ),
                  title: 'Change Theme',
                  subtitle: 'Accent palette: ${paletteId.toUpperCase()}',
                  onTap: () => _select(context, onChangeTheme),
                ),
                ProfileActionCard(
                  icon: Icons.settings_outlined,
                  iconBackgroundColor: colors.resolve(
                    const Color(0xFFCCFBF1),
                    scheme.primaryContainer,
                  ),
                  iconColor: colors.resolve(
                    const Color(0xFF0D9488),
                    scheme.primary,
                  ),
                  title: 'Settings',
                  subtitle: 'Password, privacy, AI keys & preferences',
                  onTap: () => _select(context, onSettings),
                ),
              ],
            ),
          ),
          // Docked Sign Out button at the bottom of the sidebar
          Material(
            color: AppColors.signOutButtonRed,
            child: InkWell(
              onTap: () => _select(context, onSignOut),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Center(
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.dmSans(
                        color: AppColors.signOutTextYellow,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
