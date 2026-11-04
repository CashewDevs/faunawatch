import 'dart:typed_data';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-a';

void main() {
  late FakeKeyStorage keys;
  late Map<AiProvider, FakeVisionClient> clients;
  late FakePreferencesService preferences;

  setUp(() {
    keys = FakeKeyStorage();
    clients = {
      for (final provider in AiProvider.values)
        provider: FakeVisionClient(defaultModel: '${provider.name}-default'),
    };
    preferences = FakePreferencesService();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value(_user)),
          aiApiKeyStorageServiceProvider.overrideWithValue(keys),
          aiPreferencesServiceProvider.overrideWithValue(preferences),
          aiIntegrationServiceProvider.overrideWithValue(
            AiIntegrationService(
              keys: keys,
              clients: clients,
              testImage: () async => Uint8List.fromList([1]),
            ),
          ),
          windowSecurityServiceProvider.overrideWithValue(_NoWindowSecurity()),
        ],
        child: const MaterialApp(home: AiIntegrationView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows provider, key, model and test rows', (tester) async {
    keys.keys[(_user, AiProvider.openRouter)] = 'k';
    await pump(tester);

    expect(find.text('AI Integration'), findsOneWidget);
    expect(find.text('AI provider'), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Configured'), findsOneWidget);
    expect(find.text('openRouter-default (default)'), findsOneWidget);
    expect(find.text('Tap refresh to load available models'), findsOneWidget);
    expect(find.text('Test API'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a provider updates the screen and saves it', (
    tester,
  ) async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    await pump(tester);
    expect(find.text('Gemini'), findsOneWidget);

    await tester.tap(find.text('AI provider'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Key added'), findsOneWidget);
    expect(find.textContaining('No key yet'), findsNWidgets(2));
    await tester.tap(find.text('Groq'));
    await tester.pumpAndSettle();

    expect(find.text('Groq'), findsOneWidget);
    expect(find.text('Not added. Tap to add a Groq key.'), findsOneWidget);
    expect(preferences.saved[_user]!.provider, AiProvider.groq);
  });

  testWidgets('refresh loads models and the picker saves one', (tester) async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    clients[AiProvider.gemini]!.models = const [
      AiModelOption(id: 'gemini-3.6-flash', name: 'Gemini 3.6 Flash'),
      AiModelOption(id: 'gemini-3.5-flash', name: 'Gemini 3.5 Flash'),
    ];
    await pump(tester);

    await tester.tap(find.byTooltip('Refresh models'));
    await tester.pumpAndSettle();
    expect(find.text('Tap refresh to load available models'), findsNothing);

    await tester.tap(find.text('Model'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini models'), findsOneWidget);
    expect(find.text('Use the default'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '3.5');
    await tester.pumpAndSettle();
    expect(find.text('Gemini 3.6 Flash'), findsNothing);
    await tester.tap(find.text('Gemini 3.5 Flash'));
    await tester.pumpAndSettle();

    expect(find.text('gemini-3.5-flash'), findsOneWidget);
    expect(preferences.saved[_user]!.models, {
      AiProvider.gemini: 'gemini-3.5-flash',
    });
  });

  testWidgets('tapping Model loads the list first when needed', (tester) async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    await pump(tester);

    await tester.tap(find.text('Model'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini models'), findsOneWidget);
    expect(find.text('listed-model'), findsOneWidget);
  });

  testWidgets('a failed model list explains why', (tester) async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    clients[AiProvider.gemini]!.failure = AiVisionFailure.invalidKey;
    await pump(tester);

    await tester.tap(find.byTooltip('Refresh models'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gemini rejected the key. Check or replace it.'),
      findsOneWidget,
    );
  });

  testWidgets('Test API shows API ready', (tester) async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    preferences.saved[_user] = const AiPreferences(
      models: {AiProvider.gemini: 'picked'},
    );
    await pump(tester);

    await tester.tap(find.text('Test API'));
    await tester.pumpAndSettle();

    expect(find.text('API ready'), findsOneWidget);
    expect(clients[AiProvider.gemini]!.modelsUsed, ['picked']);
  });

  testWidgets('Test API explains a model that refuses photos', (tester) async {
    keys.keys[(_user, AiProvider.groq)] = 'k';
    preferences.saved[_user] = const AiPreferences(provider: AiProvider.groq);
    clients[AiProvider.groq]!.failure = AiVisionFailure.badResponse;
    await pump(tester);

    await tester.tap(find.text('Test API'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "This model didn't accept the test photo. Pick one that takes images.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('the API key row opens the key manager and picks up new keys', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Not added. Tap to add a Gemini key.'), findsOneWidget);

    await tester.tap(find.text('API key'));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeySetupView), findsOneWidget);

    keys.keys[(_user, AiProvider.gemini)] = 'new';
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Configured'), findsOneWidget);
  });
}

class _NoWindowSecurity implements WindowSecurityService {
  @override
  Future<void> enableSecure() async {}

  @override
  Future<void> disableSecure() async {}
}
