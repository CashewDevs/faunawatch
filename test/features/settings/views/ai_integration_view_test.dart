import 'dart:typed_data';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/core/services/external_link_service.dart';
import 'package:faunawatch/core/services/window_security_service.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/views/ai_backup_key_view.dart';
import 'package:faunawatch/features/settings/views/ai_integration_view.dart';
import 'package:faunawatch/features/settings/views/ai_key_setup_view.dart';
import 'package:faunawatch/features/settings/views/widgets/ai_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-a';

void main() {
  late FakeKeyStorage keys;
  late FakeBackupKeyStorage backups;
  late Map<AiProvider, FakeVisionClient> clients;
  late FakePreferencesService preferences;
  late _FakeWindowSecurity windowSecurity;
  late _FakeLinks links;

  setUp(() {
    windowSecurity = _FakeWindowSecurity();
    links = _FakeLinks();
    keys = FakeKeyStorage();
    backups = FakeBackupKeyStorage();
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
          aiBackupKeyStorageServiceProvider.overrideWithValue(backups),
          aiPreferencesServiceProvider.overrideWithValue(preferences),
          aiIntegrationServiceProvider.overrideWithValue(
            AiIntegrationService(
              keys: keys,
              backupKeys: backups,
              clients: clients,
              testImage: () async => Uint8List.fromList([1]),
            ),
          ),
          windowSecurityServiceProvider.overrideWithValue(windowSecurity),
          externalLinkServiceProvider.overrideWithValue(links),
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

  group('API key pop-up', () {
    Future<void> openKeyPopUp(WidgetTester tester) async {
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      expect(find.byType(AiKeyDialog), findsOneWidget);
    }

    testWidgets('saves a typed key only after agreeing', (tester) async {
      await pump(tester);
      expect(find.text('Not added. Tap to add a Gemini key.'), findsOneWidget);

      await openKeyPopUp(tester);
      expect(find.text('Gemini API key'), findsOneWidget);
      expect(find.byType(AiKeySetupView), findsNothing);
      expect(windowSecurity.isSecure, isTrue);

      await tester.enterText(find.byType(TextField), 'new-key');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Before we save your Gemini key'), findsOneWidget);
      expect(keys.keys, isEmpty);

      await tester.tap(find.text('I agree to the AI Keys Agreement'));
      await tester.pump();
      await tester.tap(find.text('Agree & save key'));
      await tester.pumpAndSettle();

      expect(keys.keys[(_user, AiProvider.gemini)], 'new-key');
      expect(find.byType(AiKeyDialog), findsNothing);
      expect(find.text('Configured'), findsOneWidget);
      expect(find.text('Gemini key saved.'), findsOneWidget);
      expect(windowSecurity.isSecure, isFalse);
    });

    testWidgets('declining the agreement keeps the pop-up and typed key', (
      tester,
    ) async {
      await pump(tester);
      await openKeyPopUp(tester);
      await tester.enterText(find.byType(TextField), 'typed-key');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(keys.keys, isEmpty);
      expect(find.byType(AiKeyDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'typed-key',
      );
    });

    testWidgets('Save waits for a typed key and Cancel closes', (tester) async {
      await pump(tester);
      await openKeyPopUp(tester);

      final save = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Remove'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AiKeyDialog), findsNothing);
      expect(windowSecurity.isSecure, isFalse);
    });

    testWidgets('removes a saved key after confirming', (tester) async {
      keys.keys[(_user, AiProvider.gemini)] = 'saved-secret';
      await pump(tester);
      await openKeyPopUp(tester);

      expect(
        find.text('A key is saved. Paste a new one to replace it.'),
        findsOneWidget,
      );
      expect(find.text('saved-secret'), findsNothing);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Gemini key?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(keys.keys, isNotEmpty);
      expect(find.byType(AiKeyDialog), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(keys.keys, isEmpty);
      expect(find.byType(AiKeyDialog), findsNothing);
      expect(find.text('Not added. Tap to add a Gemini key.'), findsOneWidget);
    });

    testWidgets('the key link opens the provider page', (tester) async {
      await pump(tester);
      await openKeyPopUp(tester);

      await tester.tap(find.text('Where do I get a Gemini key?'));
      await tester.pump();

      expect(links.opened, [AiProvider.gemini.keyConsoleUri]);
    });
  });

  group('backup key', () {
    testWidgets('without a backup shows only the setup row', (tester) async {
      keys.keys[(_user, AiProvider.gemini)] = 'k';
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Backup key'), 200);

      expect(find.text('BACKUP KEY'), findsOneWidget);
      expect(find.text('Not set up. Tap to add one.'), findsOneWidget);
      expect(find.text('Test backup'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a saved backup shows its provider, model and a test', (
      tester,
    ) async {
      keys.keys[(_user, AiProvider.gemini)] = 'k';
      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Test backup'), 200);

      expect(find.text('Groq · groq-default'), findsOneWidget);
      await tester.tap(find.text('Test backup'));
      await tester.pumpAndSettle();

      expect(find.text('Backup key ready'), findsOneWidget);
      expect(clients[AiProvider.groq]!.keysUsed, ['groq-backup']);
      expect(clients[AiProvider.gemini]!.keysUsed, isEmpty);
    });

    testWidgets('a failing backup test names the backup provider', (
      tester,
    ) async {
      keys.keys[(_user, AiProvider.gemini)] = 'k';
      backups.backups[_user] = (AiProvider.openRouter, 'or-backup');
      clients[AiProvider.openRouter]!.failure = AiVisionFailure.invalidKey;
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Test backup'), 200);

      await tester.tap(find.text('Test backup'));
      await tester.pumpAndSettle();
      expect(
        find.text('OpenRouter rejected the key. Check or replace it.'),
        findsOneWidget,
      );
    });

    testWidgets('the backup row opens the backup screen and picks up a key', (
      tester,
    ) async {
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Backup key'), 200);
      await tester.tap(find.text('Backup key'));
      await tester.pumpAndSettle();
      expect(find.byType(AiBackupKeyView), findsOneWidget);

      backups.backups[_user] = (AiProvider.gemini, 'gemini-backup');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(AiBackupKeyView), findsNothing);
      expect(find.text('Gemini · gemini-default'), findsOneWidget);
    });
  });
}

class _FakeWindowSecurity implements WindowSecurityService {
  bool isSecure = false;

  @override
  Future<void> enableSecure() async => isSecure = true;

  @override
  Future<void> disableSecure() async => isSecure = false;
}

class _FakeLinks implements ExternalLinkService {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
