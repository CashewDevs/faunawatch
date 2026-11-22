import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/profile/viewmodels/settings_viewmodel.dart';
import 'package:faunawatch/features/profile/views/change_password_view.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/about_ai_reports_view.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:faunawatch/features/profile/views/settings_view.dart';

void main() {
  Widget buildTestSettings() {
    return const ProviderScope(child: MaterialApp(home: SettingsView()));
  }

  group('SettingsView', () {
    testWidgets('renders Account, Privacy below Account, and preferences', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestSettings());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Update your sign-in password'), findsOneWidget);
      expect(find.text('PRIVACY'), findsOneWidget);
      expect(find.text('Show approximate location'), findsOneWidget);
      expect(
        find.text('Other users see a nearby area, not your exact spot'),
        findsOneWidget,
      );
      expect(find.text('Hide my name on reports'), findsOneWidget);
      expect(find.text('Post as "Anonymous spotter"'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('PRIVACY')).dy,
        greaterThan(tester.getBottomLeft(find.text('Change password')).dy),
      );
      expect(find.text('Theme Mode'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
    });

    testWidgets('toggling Privacy switches updates SettingsViewModel', (
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

      final switches = find.byType(Switch);
      expect(
        container.read(settingsViewModelProvider).locationPrivacyEnabled,
        isTrue,
      );
      expect(
        container.read(settingsViewModelProvider).hideNameOnReports,
        isFalse,
      );

      await tester.tap(switches.at(0));
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();

      expect(
        container.read(settingsViewModelProvider).locationPrivacyEnabled,
        isFalse,
      );
      expect(
        container.read(settingsViewModelProvider).hideNameOnReports,
        isTrue,
      );
    });

    testWidgets('tapping Change password opens ChangePasswordView', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestSettings());

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordView), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update password'), findsOneWidget);
    });
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

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI Integration'));
      await tester.pumpAndSettle();

      expect(find.byType(AiIntegrationView), findsOneWidget);
      expect(find.text('AI provider'), findsOneWidget);
      expect(find.text('Test API'), findsOneWidget);
    });

    testWidgets('tapping About AI results opens AboutAiReportsView', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithKeys(_FakeKeyStorage()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('About AI results'), findsOneWidget);
      expect(
        find.text(
          'Preliminary guesses only, not veterinary or wildlife-authority advice',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('About AI results'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutAiReportsView), findsOneWidget);
      expect(find.text('About AI Reports'), findsOneWidget);
      expect(
        find.text('AI gives a first guess, not an answer'),
        findsOneWidget,
      );
      expect(find.text('What the AI looks at'), findsOneWidget);
      expect(find.text('What the labels mean'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Uncertain'), findsNothing);
      expect(find.text('What AI cannot do'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('If AI is not available'), findsOneWidget);
      expect(find.text('Your photos and AI'), findsOneWidget);
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
