import 'dart:typed_data';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/ai/ai_vision_client.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_integration_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_integration_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fauna_lens/ai_fakes.dart';

const _user = 'user-a';

void main() {
  late FakeKeyStorage keys;
  late FakeBackupKeyStorage backups;
  late Map<AiProvider, FakeVisionClient> clients;
  late FakePreferencesService preferences;

  setUp(() {
    keys = FakeKeyStorage();
    backups = FakeBackupKeyStorage();
    clients = {
      for (final provider in AiProvider.values)
        provider: FakeVisionClient(defaultModel: '${provider.name}-default'),
    };
    preferences = FakePreferencesService();
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(_user)),
        aiPreferencesServiceProvider.overrideWithValue(preferences),
        aiIntegrationServiceProvider.overrideWithValue(
          AiIntegrationService(
            keys: keys,
            backupKeys: backups,
            clients: clients,
            testImage: () async => Uint8List.fromList([1]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(aiIntegrationViewModelProvider.future);
    return container;
  }

  AiIntegrationState stateOf(ProviderContainer container) =>
      container.read(aiIntegrationViewModelProvider).requireValue;

  AiIntegrationViewModel viewModelOf(ProviderContainer container) =>
      container.read(aiIntegrationViewModelProvider.notifier);

  group('backup key', () {
    test('starts with no backup', () async {
      final state = stateOf(await makeContainer());
      expect(state.hasBackup, isFalse);
      expect(state.backupModel, isNull);
    });

    test(
      "uses the backup's own model for its provider, else the default",
      () async {
        backups.backups[_user] = (AiProvider.groq, 'backup');
        preferences.saved[_user] = const AiPreferences(
          // The main choice for Groq does not change the backup's model.
          models: {AiProvider.groq: 'groq-main'},
          backupModels: {AiProvider.groq: 'groq-backup-pick'},
        );
        var state = stateOf(await makeContainer());
        expect(state.backupProvider, AiProvider.groq);
        expect(state.backupModel, 'groq-backup-pick');
        expect(state.usesDefaultBackupModel, isFalse);

        preferences.saved[_user] = const AiPreferences(
          models: {AiProvider.groq: 'groq-main'},
        );
        state = stateOf(await makeContainer());
        expect(state.backupModel, 'groq-default');
        expect(state.usesDefaultBackupModel, isTrue);
      },
    );

    test('Test backup passes or explains the failure', () async {
      backups.backups[_user] = (AiProvider.openRouter, 'or-backup');
      final container = await makeContainer();

      await viewModelOf(container).testBackup();
      expect(stateOf(container).backupTestStatus, AiTestStatus.passed);
      expect(clients[AiProvider.openRouter]!.keysUsed, ['or-backup']);
      expect(clients[AiProvider.openRouter]!.modelsUsed, [
        'openRouter-default',
      ]);
      // The main test result is separate.
      expect(stateOf(container).testStatus, AiTestStatus.idle);

      clients[AiProvider.openRouter]!.failure = AiVisionFailure.invalidKey;
      await viewModelOf(container).testBackup();
      expect(stateOf(container).backupTestStatus, AiTestStatus.failed);
      expect(
        stateOf(container).backupTestFailure,
        AiIntegrationFailure.invalidKey,
      );
    });

    test('refreshKeys picks up an added, replaced or removed backup', () async {
      final container = await makeContainer();
      final viewModel = viewModelOf(container);

      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      await viewModel.refreshKeys();
      expect(stateOf(container).backupProvider, AiProvider.groq);

      await viewModel.testBackup();
      expect(stateOf(container).backupTestStatus, AiTestStatus.passed);

      backups.backups[_user] = (AiProvider.gemini, 'gemini-backup');
      await viewModel.refreshKeys();
      expect(stateOf(container).backupProvider, AiProvider.gemini);
      expect(stateOf(container).backupTestStatus, AiTestStatus.idle);

      backups.backups.remove(_user);
      await viewModel.refreshKeys();
      expect(stateOf(container).hasBackup, isFalse);
    });

    test(
      'saving a backup key stores it and resets its model list and test',
      () async {
        backups.backups[_user] = (AiProvider.groq, 'groq-backup');
        final container = await makeContainer();
        final viewModel = viewModelOf(container);
        await viewModel.loadBackupModels();
        await viewModel.testBackup();
        expect(stateOf(container).backupAvailableModels, isNotNull);
        expect(stateOf(container).backupTestStatus, AiTestStatus.passed);

        // A new key for the same provider still clears the old results.
        expect(await viewModel.saveBackupKey(AiProvider.groq, ' new '), isTrue);
        expect(backups.backups[_user], (AiProvider.groq, 'new'));
        expect(stateOf(container).backupAvailableModels, isNull);
        expect(stateOf(container).backupTestStatus, AiTestStatus.idle);

        expect(await viewModel.saveBackupKey(AiProvider.gemini, 'g'), isTrue);
        expect(stateOf(container).backupProvider, AiProvider.gemini);
        expect(stateOf(container).backupModel, 'gemini-default');
      },
    );

    test('a failed backup save keeps the old backup', () async {
      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      final container = await makeContainer();
      backups.saveError = StateError('storage');

      expect(
        await viewModelOf(container).saveBackupKey(AiProvider.gemini, 'g'),
        isFalse,
      );
      expect(stateOf(container).backupProvider, AiProvider.groq);
    });

    test('removing the backup key clears it', () async {
      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      final container = await makeContainer();

      expect(await viewModelOf(container).removeBackupKey(), isTrue);
      expect(backups.backups, isEmpty);
      expect(stateOf(container).hasBackup, isFalse);
      expect(stateOf(container).backupModel, isNull);
    });

    test('loads backup models with the backup key', () async {
      keys.keys[(_user, AiProvider.gemini)] = 'main';
      backups.backups[_user] = (AiProvider.openRouter, 'or-backup');
      final container = await makeContainer();

      await viewModelOf(container).loadBackupModels();

      expect(stateOf(container).backupAvailableModels, hasLength(1));
      expect(clients[AiProvider.openRouter]!.keysUsed, ['or-backup']);
      expect(clients[AiProvider.gemini]!.keysUsed, isEmpty);
      // The main provider's list is separate.
      expect(stateOf(container).availableModels, isNull);
    });

    test('a failed backup model list is shown', () async {
      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      clients[AiProvider.groq]!.failure = AiVisionFailure.invalidKey;
      final container = await makeContainer();

      await viewModelOf(container).loadBackupModels();

      expect(
        stateOf(container).backupModelsFailure,
        AiIntegrationFailure.invalidKey,
      );
      expect(stateOf(container).isLoadingBackupModels, isFalse);
    });

    test('picking a backup model saves it apart from the main model', () async {
      keys.keys[(_user, AiProvider.groq)] = 'main';
      backups.backups[_user] = (AiProvider.groq, 'groq-backup');
      preferences.saved[_user] = const AiPreferences(provider: AiProvider.groq);
      final container = await makeContainer();
      final viewModel = viewModelOf(container);
      await viewModel.testBackup();

      await viewModel.selectBackupModel('groq/backup');
      expect(stateOf(container).backupModel, 'groq/backup');
      expect(stateOf(container).model, 'groq-default');
      expect(stateOf(container).backupTestStatus, AiTestStatus.idle);
      expect(preferences.saved[_user]!.backupModels, {
        AiProvider.groq: 'groq/backup',
      });

      await viewModel.testBackup();
      expect(clients[AiProvider.groq]!.modelsUsed.last, 'groq/backup');

      // Changing the main model leaves the backup's model and test alone.
      await viewModel.selectModel('groq/main');
      expect(stateOf(container).backupModel, 'groq/backup');
      expect(stateOf(container).backupTestStatus, AiTestStatus.passed);

      await viewModel.selectBackupModel(null);
      expect(stateOf(container).usesDefaultBackupModel, isTrue);
    });
  });

  test('starts from saved choices and key status', () async {
    keys.keys[(_user, AiProvider.groq)] = 'k';
    preferences.saved[_user] = const AiPreferences(
      provider: AiProvider.groq,
      models: {AiProvider.groq: 'picked'},
    );

    final state = stateOf(await makeContainer());

    expect(state.provider, AiProvider.groq);
    expect(state.providerHasKey, isTrue);
    expect(state.model, 'picked');
    expect(state.usesDefaultModel, isFalse);
    expect(state.availableModels, isNull);
    expect(state.testStatus, AiTestStatus.idle);
  });

  test('without a choice, uses the provider that has a key and its '
      'default model', () async {
    keys.keys[(_user, AiProvider.openRouter)] = 'k';

    final state = stateOf(await makeContainer());

    expect(state.provider, AiProvider.openRouter);
    expect(state.model, 'openRouter-default');
    expect(state.usesDefaultModel, isTrue);
  });

  test(
    'choosing a provider saves it and clears the old list and test',
    () async {
      keys.keys[(_user, AiProvider.gemini)] = 'k';
      final container = await makeContainer();
      await viewModelOf(container).loadModels();
      await viewModelOf(container).testConnection();

      await viewModelOf(container).selectProvider(AiProvider.groq);

      final state = stateOf(container);
      expect(state.provider, AiProvider.groq);
      expect(state.providerHasKey, isFalse);
      expect(state.availableModels, isNull);
      expect(state.testStatus, AiTestStatus.idle);
      expect(preferences.saved[_user]!.provider, AiProvider.groq);
    },
  );

  test('loads models and saves the picked one', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    clients[AiProvider.gemini]!.models = const [
      AiModelOption(id: 'a'),
      AiModelOption(id: 'b'),
    ];
    final container = await makeContainer();

    await viewModelOf(container).loadModels();
    expect(stateOf(container).availableModels!.map((m) => m.id), ['a', 'b']);

    await viewModelOf(container).selectModel('b');
    expect(stateOf(container).model, 'b');
    expect(preferences.saved[_user]!.models, {AiProvider.gemini: 'b'});

    await viewModelOf(container).selectModel(null);
    expect(stateOf(container).model, 'gemini-default');
    expect(preferences.saved[_user]!.models, isEmpty);
  });

  test('a failed model list is shown', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    clients[AiProvider.gemini]!.failure = AiVisionFailure.invalidKey;
    final container = await makeContainer();

    await viewModelOf(container).loadModels();

    final state = stateOf(container);
    expect(state.isLoadingModels, isFalse);
    expect(state.availableModels, isNull);
    expect(state.modelsFailure, AiIntegrationFailure.invalidKey);
  });

  test('the test passes with the chosen model', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    preferences.saved[_user] = const AiPreferences(
      models: {AiProvider.gemini: 'picked'},
    );
    final container = await makeContainer();

    final running = viewModelOf(container).testConnection();
    expect(stateOf(container).isTesting, isTrue);
    await running;

    expect(stateOf(container).testStatus, AiTestStatus.passed);
    expect(clients[AiProvider.gemini]!.modelsUsed, ['picked']);
  });

  test('the test reports why it failed', () async {
    final container = await makeContainer();

    await viewModelOf(container).testConnection();

    final state = stateOf(container);
    expect(state.testStatus, AiTestStatus.failed);
    expect(state.testFailure, AiIntegrationFailure.noKey);
  });

  test('changing the model clears a passed test', () async {
    keys.keys[(_user, AiProvider.gemini)] = 'k';
    final container = await makeContainer();
    await viewModelOf(container).testConnection();

    await viewModelOf(container).selectModel('other');

    expect(stateOf(container).testStatus, AiTestStatus.idle);
  });

  test('refreshKeys picks up a key added elsewhere', () async {
    final container = await makeContainer();
    expect(stateOf(container).providerHasKey, isFalse);

    keys.keys[(_user, AiProvider.gemini)] = 'new';
    await viewModelOf(container).refreshKeys();

    expect(stateOf(container).providerHasKey, isTrue);
  });
}
