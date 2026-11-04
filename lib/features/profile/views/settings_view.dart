import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/sign_out_dialog.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';

/// The Settings screen featuring Theme Mode (Light/Dark/System), AI provider
/// keys, application preferences, and the docked Sign Out button.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  void _showSignOutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const SignOutConfirmationDialog(),
    );
  }

  void _openAiKeys(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiIntegrationView()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
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
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.shellHeaderBlue,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: GoogleFonts.dmSans(
                        color: AppColors.shellHeaderBlue,
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
                    // Theme Mode Section Header
                    _buildSectionHeader('APPEARANCE', isDark),
                    const SizedBox(height: 8),

                    // Light / Dark / System Segmented Control Card
                    Container(
                      padding: const EdgeInsets.all(16),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Mode',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Switch between light and dark display modes across the app.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildThemeModeOption(
                                  context: context,
                                  ref: ref,
                                  title: 'Light',
                                  icon: Icons.light_mode_rounded,
                                  mode: ThemeMode.light,
                                  isSelected: themeMode == ThemeMode.light,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildThemeModeOption(
                                  context: context,
                                  ref: ref,
                                  title: 'Dark',
                                  icon: Icons.dark_mode_rounded,
                                  mode: ThemeMode.dark,
                                  isSelected: themeMode == ThemeMode.dark,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildThemeModeOption(
                                  context: context,
                                  ref: ref,
                                  title: 'System',
                                  icon: Icons.brightness_auto_rounded,
                                  mode: ThemeMode.system,
                                  isSelected: themeMode == ThemeMode.system,
                                  isDark: isDark,
                                ),
                              ),
                            ],
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
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
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
                              activeTrackColor: AppColors.shellHeaderBlue,
                            ),
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                            SwitchListTile.adaptive(
                              value: settings.locationPrivacyEnabled,
                              onChanged: (val) {
                                ref
                                    .read(settingsViewModelProvider.notifier)
                                    .toggleLocationPrivacy(val);
                              },
                              title: Text(
                                'Location Privacy',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: Text(
                                'Obfuscate precise location coordinates on reports',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              activeTrackColor: AppColors.shellHeaderBlue,
                            ),
                          ],
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

  Widget _buildThemeModeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.shellHeaderBlue
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.shellHeaderBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569)),
              ),
            ),
          ],
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
