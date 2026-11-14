import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/profile/models/theme_palette.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';

/// Resolves the profile selection for both brightness variants of the app.
final activeThemePaletteProvider = Provider<AppThemePalette>((ref) {
  final id = ref.watch(
    settingsViewModelProvider.select((settings) => settings.activePaletteId),
  );
  return AppThemePalette.presets.firstWhere(
    (palette) => palette.id == id,
    orElse: () => AppThemePalette.presets.first,
  );
});

final appLightThemeProvider = Provider<ThemeData>(
  (ref) => AppTheme.forPalette(
    ref.watch(activeThemePaletteProvider),
    brightness: Brightness.light,
  ),
);

final appDarkThemeProvider = Provider<ThemeData>(
  (ref) => AppTheme.forPalette(
    ref.watch(activeThemePaletteProvider),
    brightness: Brightness.dark,
  ),
);

/// State notifier managing the active application ThemeMode (Light, Dark, or System).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  /// Sets the active [ThemeMode].
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

/// Riverpod provider exposing the current [ThemeMode].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
