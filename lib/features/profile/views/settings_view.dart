import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/change_password_view.dart';
import 'package:faunawatch/features/profile/views/widgets/sign_out_dialog.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';

/// The Settings screen featuring account security (Change password), AI
/// provider keys, application preferences, and the docked Sign Out button.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  void _showSignOutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const SignOutConfirmationDialog(),
    );
  }

  void _openChangePassword(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordView()));
  }

  void _openAiKeys(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiIntegrationView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final savedKeyCount = ref
        .watch(aiKeySettingsViewModelProvider)
        .asData
        ?.value
        .configuredProviders
        .values
        .where((saved) => saved)
        .length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Container(
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
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with back chevron and title (except the headers part)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: AppPaletteColors.of(context).shellHeaderBlue,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: GoogleFonts.dmSans(
                        color: AppPaletteColors.of(context).shellHeaderBlue,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Settings scrollable body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Account Section
                    _buildSectionHeader('ACCOUNT', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.04,
                            ),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openChangePassword(context),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF0E7A5F,
                                          ).withValues(alpha: 0.22)
                                        : const Color(0xFFD9F5EC),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.lock_outline_rounded,
                                    color: isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF0E7A5F),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Change password',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Update your sign-in password',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Privacy Section
                    _buildSectionHeader('PRIVACY', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.04,
                            ),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildPrivacyToggleRow(
                            context: context,
                            icon: Icons.shield_outlined,
                            iconBackground: isDark
                                ? const Color(
                                    0xFF1A5DC9,
                                  ).withValues(alpha: 0.22)
                                : const Color(0xFFE3F0FE),
                            iconColor: isDark
                                ? AppColors.darkAccentBlue
                                : const Color(0xFF1A5DC9),
                            title: 'Show approximate location',
                            subtitle:
                                'Other users see a nearby area, not your exact spot',
                            value: settings.locationPrivacyEnabled,
                            isDark: isDark,
                            onChanged: (val) => ref
                                .read(settingsViewModelProvider.notifier)
                                .toggleLocationPrivacy(val),
                          ),
                          const SizedBox(height: 16),
                          _buildPrivacyToggleRow(
                            context: context,
                            icon: Icons.image_outlined,
                            iconBackground: isDark
                                ? const Color(
                                    0xFFB91C1C,
                                  ).withValues(alpha: 0.22)
                                : const Color(0xFFFDE8E8),
                            iconColor: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFB91C1C),
                            title: 'Hide my name on reports',
                            subtitle: 'Post as "Anonymous spotter"',
                            value: settings.hideNameOnReports,
                            isDark: isDark,
                            onChanged: (val) => ref
                                .read(settingsViewModelProvider.notifier)
                                .toggleHideNameOnReports(val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Preferences Section
                    _buildSectionHeader('PREFERENCES', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.04,
                            ),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: SwitchListTile.adaptive(
                          value: settings.pushNotificationsEnabled,
                          onChanged: (val) {
                            ref
                                .read(settingsViewModelProvider.notifier)
                                .togglePushNotifications(val);
                          },
                          title: Text(
                            'Push Notifications',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            'Receive alerts on community sightings and replies',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          activeTrackColor: AppPaletteColors.of(
                            context,
                          ).shellHeaderBlue,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // AI keys section
                    _buildSectionHeader('AI', isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.04,
                            ),
                            offset: const Offset(0, 3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          onTap: () => _openAiKeys(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            'AI Integration',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            'Provider, model, API keys and connection test',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          trailing: savedKeyCount == null
                              ? const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF94A3B8),
                                )
                              : _AiKeyStatusChip(savedKeyCount: savedKeyCount),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // About section
                    _buildSectionHeader('ABOUT', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'FaunaWatch Version',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '1.0.0',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Docked full-width Sign Out button matching image specification
      bottomNavigationBar: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => _showSignOutDialog(context),
          child: Container(
            width: double.infinity,
            height: 56,
            color: AppColors.signOutButtonRed,
            alignment: Alignment.center,
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
    );
  }

  Widget _buildPrivacyToggleRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  height: 1.3,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppPaletteColors.of(context).shellHeaderBlue,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Trailing chip on the AI keys row: how many keys are saved, or a prompt to
/// finish setup when none are.
class _AiKeyStatusChip extends StatelessWidget {
  const _AiKeyStatusChip({required this.savedKeyCount});

  final int savedKeyCount;

  @override
  Widget build(BuildContext context) {
    final needsSetup = savedKeyCount == 0;
    final label = needsSetup
        ? 'SET UP'
        : '$savedKeyCount ${savedKeyCount == 1 ? 'KEY' : 'KEYS'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: needsSetup
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: needsSetup
                  ? const Color(0xFFB45309)
                  : const Color(0xFF15803D),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
          size: 18,
        ),
      ],
    );
  }
}
