import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';
import 'package:faunawatch/features/welcome/views/welcome_view.dart';

void main() {
  Widget buildTestSettings() {
    return const ProviderScope(child: MaterialApp(home: SettingsView()));
  }

  group('SettingsView', () {
    testWidgets(
      'renders theme mode options, preferences, and docked sign out',
      (tester) async {
        await tester.pumpWidget(buildTestSettings());

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Theme Mode'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Push Notifications'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
      },
    );

    testWidgets('tapping Light theme option updates themeModeProvider', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsView()),
        ),
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets(
      'tapping docked Sign Out shows confirmation modal and redirects on confirm',
      (tester) async {
        await tester.pumpWidget(buildTestSettings());

        // Tap docked Sign Out
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Are you sure you want to sign out? You will need to log back in to access your reports and messages.',
          ),
          findsOneWidget,
        );

        // Tap confirm Sign Out in modal
        final confirmButtons = find.widgetWithText(ElevatedButton, 'Sign Out');
        expect(confirmButtons, findsOneWidget);

        await tester.tap(confirmButtons);
        await tester.pumpAndSettle();

        // Redirects to WelcomeView (the very first screen)
        expect(find.byType(WelcomeView), findsOneWidget);
      },
    );
  });
}
