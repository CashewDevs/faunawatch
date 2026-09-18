import 'package:flutter/material.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/shell/views/shell_view.dart';

/// Root application widget for FaunaWatch.
class FaunaWatchApp extends StatelessWidget {
  const FaunaWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaunaWatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const ShellView(),
    );
  }
}
