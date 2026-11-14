import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/features/splash/views/splash_view.dart';

/// Root application widget for FaunaWatch.
class FaunaWatchApp extends ConsumerWidget {
  const FaunaWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FaunaWatch',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appLightThemeProvider),
      darkTheme: ref.watch(appDarkThemeProvider),
      themeMode: themeMode,
      home: const SplashView(),
    );
  }
}
