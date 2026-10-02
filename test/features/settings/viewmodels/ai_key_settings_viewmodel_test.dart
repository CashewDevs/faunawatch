import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';

void main() {
  group('AiKeySettingsViewModel', () {
    late ProviderContainer container;
    late _FakeAiApiKeyStorageService storage;

    setUp(() {
      storage = _FakeAiApiKeyStorageService();
      container = ProviderContainer(
        overrides: [
          aiApiKeyStorageServiceProvider.overrideWithValue(storage),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('loads configured status without exposing saved key values', () async {
      storage.keys[AiProvider.groq] = 'test-secret';

      final state = await container.read(aiKeySettingsViewModelProvider.future);

      expect(state.configuredProviders[AiProvider.groq], isTrue);
      expect(state.configuredProviders[AiProvider.gemini], isFalse);
      expect(state.toString(), isNot(contains('test-secret')));
    });

    test('saves and removes a key for the selected provider', () async {
      await container.read(aiKeySettingsViewModelProvider.future);
      final viewModel =
          container.read(aiKeySettingsViewModelProvider.notifier);

      viewModel.selectProvider(AiProvider.openRouter);
      expect(await viewModel.saveKey('openrouter-secret'), isTrue);
      expect(storage.keys[AiProvider.openRouter], 'openrouter-secret');
      expect(
        container
            .read(aiKeySettingsViewModelProvider)
            .requireValue
            .selectedProviderIsConfigured,
        isTrue,
      );

      expect(await viewModel.removeKey(), isTrue);
      expect(storage.keys.containsKey(AiProvider.openRouter), isFalse);
      expect(
        container
            .read(aiKeySettingsViewModelProvider)
            .requireValue
            .selectedProviderIsConfigured,
        isFalse,
      );
    });
  });
}

class _FakeAiApiKeyStorageService implements AiApiKeyStorageService {
  final Map<AiProvider, String> keys = {};

  @override
  Future<String?> readKey(AiProvider provider) async => keys[provider];

  @override
  Future<void> saveKey(AiProvider provider, String apiKey) async {
    keys[provider] = apiKey;
  }

  @override
  Future<void> deleteKey(AiProvider provider) async {
    keys.remove(provider);
  }
}