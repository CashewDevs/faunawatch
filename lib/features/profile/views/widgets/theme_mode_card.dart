import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';

/// Appearance section allowing users to switch between Light, Dark, and System
/// display modes.
class ThemeModeCard extends ConsumerWidget {
  const ThemeModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Switch between light and dark display modes across the app.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ThemeModeOption(
                    title: 'Light',
                    icon: Icons.light_mode_rounded,
                    mode: ThemeMode.light,
                    isSelected: themeMode == ThemeMode.light,
                    isDark: isDark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeModeOption(
                    title: 'Dark',
                    icon: Icons.dark_mode_rounded,
                    mode: ThemeMode.dark,
                    isSelected: themeMode == ThemeMode.dark,
                    isDark: isDark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeModeOption(
                    title: 'System',
                    icon: Icons.brightness_auto_rounded,
                    mode: ThemeMode.system,
                    isSelected: themeMode == ThemeMode.system,
                    isDark: isDark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.title,
    required this.icon,
    required this.mode,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final ThemeMode mode;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.shellHeaderBlue
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? palette.shellHeaderBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? palette.onPrimary
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569)),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? palette.onPrimary
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
