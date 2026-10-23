import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
