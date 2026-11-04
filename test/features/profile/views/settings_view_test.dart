import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
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

  group('SettingsView AI keys', () {
    Widget buildWithKeys(_FakeKeyStorage keyStorage) {
      return ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value('user-a')),
          aiApiKeyStorageServiceProvider.overrideWithValue(keyStorage),
          aiPreferencesServiceProvider.overrideWithValue(
            FakePreferencesService(),
          ),
          windowSecurityServiceProvider.overrideWithValue(
            _FakeWindowSecurity(),
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      );
    }

    testWidgets('prompts setup when no key is saved', (tester) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      expect(find.text('AI Integration'), findsOneWidget);
      expect(find.text('SET UP'), findsOneWidget);
    });

    testWidgets('shows how many keys are saved', (tester) async {
      final keyStorage = _FakeKeyStorage()
        ..saved.addAll({AiProvider.groq, AiProvider.gemini});
      await tester.pumpWidget(buildWithKeys(keyStorage));
      await tester.pumpAndSettle();

      expect(find.text('2 KEYS'), findsOneWidget);
      expect(find.text('SET UP'), findsNothing);
    });

    testWidgets('tapping AI Integration opens the AI Integration screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('AI Integration'));
      await tester.tap(find.text('AI Integration'));
      await tester.pumpAndSettle();

      expect(find.byType(AiIntegrationView), findsOneWidget);
      expect(find.text('AI provider'), findsOneWidget);
      expect(find.text('Test API'), findsOneWidget);
    });
  });
}

class _FakeKeyStorage implements AiApiKeyStorageService {
  final Set<AiProvider> saved = {};

  @override
  Future<String?> readKey(String userId, AiProvider provider) async =>
      saved.contains(provider) ? 'secret' : null;

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {
    saved.add(provider);
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {
    saved.remove(provider);
  }

  @override
  Future<void> deleteAllKeys(String userId) async => saved.clear();
}

class _FakeWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
