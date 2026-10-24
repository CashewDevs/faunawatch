import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/splash/views/splash_view.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

void main() {
  Widget createWidgetUnderTest({
    Duration delay = const Duration(milliseconds: 50),
    bool autoNavigate = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: SplashView(
          initializationDelay: delay,
          autoNavigate: autoNavigate,
        ),
      ),
    );
  }

  group('SplashView', () {
    testWidgets('renders placeholder elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(autoNavigate: false));

      expect(find.text('FaunaWatch'), findsOneWidget);
      expect(find.text('Splash Screen Placeholder'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('transitions to WelcomeView after initialization delay', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(delay: const Duration(milliseconds: 50)),
      );

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeView), findsOneWidget);
      expect(
        find.text('Mapping life, one sighting at a time.'),
        findsOneWidget,
      );
    });
  });
}
