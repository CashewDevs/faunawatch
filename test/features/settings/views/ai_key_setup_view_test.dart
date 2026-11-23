import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/core/theme/theme_provider.dart';
import 'package:faunawatch/core/widgets/pill_button.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_key_dialog.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_settings_card.dart';
import 'package:faunawatch/features/terms/views/terms_consent_view.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-test-001';

void main() {
  late FakeKeyStorage keys;
  late FakePreferencesService preferences;
  late _FakeLinks links;
  late _FakeWindowSecurity windowSecurity;

  setUp(() {
    keys = FakeKeyStorage();
    preferences = FakePreferencesService();
    links = _FakeLinks();
    windowSecurity = _FakeWindowSecurity();
  });

  Future<void> pumpSetup(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final backups = FakeBackupKeyStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value(_user)),
          aiApiKeyStorageServiceProvider.overrideWithValue(keys),
          aiBackupKeyStorageServiceProvider.overrideWithValue(backups),
          aiPreferencesServiceProvider.overrideWithValue(preferences),
          aiIntegrationServiceProvider.overrideWithValue(
            AiIntegrationService(
              keys: keys,
              backupKeys: backups,
              clients: {
                for (final provider in AiProvider.values)
                  provider: FakeVisionClient(
                    defaultModel: '${provider.name}-default',
                  ),
              },
              testImage: () async => Uint8List.fromList([1]),
            ),
          ),
          appLightThemeProvider.overrideWithValue(AppTheme.lightTheme),
          windowSecurityServiceProvider.overrideWithValue(windowSecurity),
          externalLinkServiceProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const AiKeySetupView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.widgetWithText(PillButton, 'Continue  >');

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<PillButton>(continueButton()).onPressed != null;

  Future<void> openKeyPopUp(WidgetTester tester) async {
    await tester.tap(find.text('API key'));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyDialog), findsOneWidget);
  }

  Future<void> typeAndAgree(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree to the AI Keys Agreement'));
    await tester.pump();
    await tester.tap(find.text('Agree & save key'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the provider and key rows in the AI Integration card', (
    tester,
  ) async {
    await pumpSetup(tester);

    expect(find.text('Power up FaunaLens'), findsOneWidget);
    expect(find.text('YOUR AI KEY'), findsOneWidget);
    expect(find.byType(AiSettingsCard), findsOneWidget);
    expect(find.text('AI provider'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('Not added. Tap to add a Gemini key.'), findsOneWidget);
    // No model or test rows during onboarding, and no key field on screen.
    expect(find.text('Model'), findsNothing);
    expect(find.text('Test API'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(continueEnabled(tester), isFalse);
    // Only the key pop-up blocks screenshots.
    expect(windowSecurity.isSecure, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a key after agreeing, then Continue goes to the terms', (
    tester,
  ) async {
    await pumpSetup(tester);

    await openKeyPopUp(tester);
    expect(find.text('Gemini API key'), findsOneWidget);
    expect(windowSecurity.isSecure, isTrue);
    await typeAndAgree(tester, 'AIza-test');

    expect(keys.keys[(_user, AiProvider.gemini)], 'AIza-test');
    expect(find.byType(AiKeyDialog), findsNothing);
    expect(find.text('Configured'), findsOneWidget);
    expect(windowSecurity.isSecure, isFalse);
    expect(continueEnabled(tester), isTrue);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    expect(find.byType(TermsConsentView), findsOneWidget);
  });

  testWidgets('declining the agreement saves nothing', (tester) async {
    await pumpSetup(tester);

    await openKeyPopUp(tester);
    await tester.enterText(find.byType(TextField), 'AIza-test');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(keys.keys, isEmpty);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('choosing a provider switches the key pop-up to it', (
    tester,
  ) async {
    await pumpSetup(tester);

    await tester.tap(find.text('AI provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groq'));
    await tester.pumpAndSettle();

    expect(find.text('Groq'), findsOneWidget);
    expect(preferences.saved[_user]!.provider, AiProvider.groq);

    await openKeyPopUp(tester);
    expect(find.text('Groq API key'), findsOneWidget);
    await typeAndAgree(tester, 'gsk-test');
    expect(keys.keys[(_user, AiProvider.groq)], 'gsk-test');
  });

  testWidgets('a saved key can be replaced but not removed here', (
    tester,
  ) async {
    keys.keys[(_user, AiProvider.gemini)] = 'saved-secret';
    await pumpSetup(tester);
    expect(find.text('Configured'), findsOneWidget);
    expect(continueEnabled(tester), isTrue);

    await openKeyPopUp(tester);

    expect(
      find.text('A key is saved. Paste a new one to replace it.'),
      findsOneWidget,
    );
    expect(find.text('saved-secret'), findsNothing);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('set up later goes to the terms without saving', (tester) async {
    await pumpSetup(tester);

    await tester.tap(find.text('Set up later'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsConsentView), findsOneWidget);
    expect(keys.keys, isEmpty);
  });

  testWidgets('the key link opens the provider page', (tester) async {
    await pumpSetup(tester);
    await openKeyPopUp(tester);

    await tester.tap(find.text('Where do I get a Gemini key?'));
    await tester.pump();

    expect(links.opened, [AiProvider.gemini.keyConsoleUri]);
  });

  testWidgets('stays light in dark mode, pop-ups included', (tester) async {
    await pumpSetup(tester, themeMode: ThemeMode.dark);

    expect(
      Theme.of(tester.element(find.text('AI provider'))).brightness,
      Brightness.light,
    );
    await openKeyPopUp(tester);
    expect(
      Theme.of(tester.element(find.text('Gemini API key'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeLinks implements ExternalLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _FakeWindowSecurity implements WindowSecurityService {
  bool isSecure = false;

  @override
  Future<void> enableSecure() async => isSecure = true;

  @override
  Future<void> disableSecure() async => isSecure = false;
}
