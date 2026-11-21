import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/profile/models/theme_palette.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';

/// Application theme definitions for FaunaWatch.
class AppTheme {
  AppTheme._();

  /// Light theme configuration
  static ThemeData get lightTheme =>
      forPalette(AppThemePalette.presets.first, brightness: Brightness.light);

  /// Dark theme configuration
  static ThemeData get darkTheme =>
      forPalette(AppThemePalette.presets.first, brightness: Brightness.dark);

  /// The accent and brightness are independent appearance choices.
  static ThemeData forPalette(
    AppThemePalette palette, {
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final isApollo = palette.id == AppThemePalette.apollo.id;
    final scheme = ColorScheme.fromSeed(
      seedColor: isApollo
          ? AppColors.primarySeed
          : Color(palette.primaryColorValue),
      brightness: brightness,
    );
    final appliedScheme = isDark
        ? scheme.copyWith(
            surface: AppColors.darkSurface,
            onSurface: Colors.white,
          )
        : scheme;
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F172A)
          : scheme.surface,
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : scheme.surfaceContainerHigh,
      ),
      colorScheme: appliedScheme,
      extensions: [
        AppPaletteColors(scheme: appliedScheme, apolloWeight: isApollo ? 1 : 0),
      ],
      dividerColor: isDark ? const Color(0xFF334155) : scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : scheme.surface,
        foregroundColor: isDark && isApollo ? Colors.white : scheme.onSurface,
      ),
    );
    return baseTheme.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme),
    );
  }
}
