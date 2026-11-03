import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/core/theme/app_theme.dart';
import 'package:faunawatch/features/intro/views/intro_view.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';

void main() {
  const userId = 'user-test-001';
  late _FakeAiApiKeyStorageService storage;
  late _FakeExternalLinkService links;
  late _FakeWindowSecurityService windowSecurity;

  setUp(() {
    storage = _FakeAiApiKeyStorageService();
    links = _FakeExternalLinkService();
    windowSecurity = _FakeWindowSecurityService();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiApiKeyStorageServiceProvider.overrideWithValue(storage),
          currentUserIdProvider.overrideWith((ref) => Stream.value(userId)),
          windowSecurityServiceProvider.overrideWithValue(windowSecurity),
          externalLinkServiceProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AiKeySetupView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.text('Continue  >');

  group('AiKeySetupView', () {
    testWidgets('shows every provider with its key status', (tester) async {
      storage.keys[(userId, AiProvider.openRouter)] = 'saved-secret';
      await pumpSetup(tester);

      expect(find.text('OpenRouter'), findsOneWidget);
      expect(find.text('Groq'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Key added'), findsOneWidget);
      expect(find.text('Add key'), findsNWidgets(2));
      expect(find.text('saved-secret'), findsNothing);
      expect(windowSecurity.isSecure, isTrue);
    });

    testWidgets('saves a typed key only after agreeing', (tester) async {
      await pumpSetup(tester);

      await tester.tap(find.text('Groq'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gsk_test');
      await tester.pump();

      // Continue with an unsaved key opens the agreement first.
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.text('Before we save your Groq key'), findsOneWidget);

      await tester.tap(find.text('Agree & save key'));
      await tester.pumpAndSettle();
      expect(find.text('Before we save your Groq key'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(storage.keys, isEmpty);
      expect(find.byType(IntroView), findsNothing);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree to the AI Keys Agreement'));
      await tester.pump();
      await tester.tap(find.text('Agree & save key'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(storage.keys[(userId, AiProvider.groq)], 'gsk_test');
      expect(find.byType(IntroView), findsOneWidget);
      expect(windowSecurity.isSecure, isFalse);
    });

    testWidgets('continue is disabled with no saved or typed key', (
      tester,
    ) async {
      await pumpSetup(tester);

      await tester.tap(continueButton());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(IntroView), findsNothing);
    });

    testWidgets('set up later goes to the intro without saving', (
      tester,
    ) async {
      await pumpSetup(tester);

      await tester.tap(find.text('Set up later'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(IntroView), findsOneWidget);
      expect(storage.keys, isEmpty);
    });

    testWidgets('opens the provider key page', (tester) async {
      await pumpSetup(tester);

      await tester.tap(find.text('Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Where do I get a Gemini key?'));
      await tester.pump();

      expect(links.opened, [AiProvider.gemini.keyConsoleUri]);
    });

    testWidgets('eye button reveals the typed key', (tester) async {
      await pumpSetup(tester);

      await tester.tap(find.text('OpenRouter'));
      await tester.pumpAndSettle();
      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue);

      await tester.tap(find.byTooltip('Show API key'));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });
  });
}

class _FakeAiApiKeyStorageService implements AiApiKeyStorageService {
  final Map<(String, AiProvider), String> keys = {};

  @override
  Future<String?> readKey(String userId, AiProvider provider) async =>
      keys[(userId, provider)];

  @override
  Future<void> saveKey(
    String userId,
    AiProvider provider,
    String apiKey,
  ) async {
    keys[(userId, provider)] = apiKey;
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) async {
    keys.remove((userId, provider));
  }

  @override
  Future<void> deleteAllKeys(String userId) async {
    keys.removeWhere((key, _) => key.$1 == userId);
  }
}

class _FakeExternalLinkService implements ExternalLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _FakeWindowSecurityService implements WindowSecurityService {
  bool isSecure = false;

  @override
  Future<void> enableSecure() async {
    isSecure = true;
  }

  @override
  Future<void> disableSecure() async {
    isSecure = false;
  }
}
