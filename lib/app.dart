import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import 'package:faunawatch/features/splash/views/splash_view.dart';
import 'package:faunawatch/features/suspension/views/suspension_gate.dart';

/// Root application widget for FaunaWatch.
class FaunaWatchApp extends ConsumerWidget {
  const FaunaWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Keeps push registration and tap handling alive for the whole session.
    ref.watch(pushViewModelProvider.select((state) => state.enabled));

    return MaterialApp(
      title: 'FaunaWatch',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appLightThemeProvider),
      darkTheme: ref.watch(appDarkThemeProvider),
      themeMode: themeMode,
      // A locked suspension replaces every screen.
      builder: (context, child) => SuspensionGate(child: child),
      home: const SplashView(),
    );
  }
}
