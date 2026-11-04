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

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value(_user)),
        aiPreferencesServiceProvider.overrideWithValue(preferences),
        aiIntegrationServiceProvider.overrideWithValue(
          AiIntegrationService(
            keys: keys,
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
