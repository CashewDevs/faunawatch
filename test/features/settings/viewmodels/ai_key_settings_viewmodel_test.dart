import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/viewmodels/ai_key_settings_viewmodel.dart';

void main() {
  group('AiKeySettingsViewModel', () {
    const userId = 'user-test-001';
    late ProviderContainer container;
    late _FakeAiApiKeyStorageService storage;

    setUp(() {
      storage = _FakeAiApiKeyStorageService();
      container = ProviderContainer(
        overrides: [
          aiApiKeyStorageServiceProvider.overrideWithValue(storage),
          currentUserIdProvider.overrideWith((ref) => userId),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('loads configured status without exposing saved key values', () async {
      storage.keys[(userId, AiProvider.groq)] = 'test-secret';

      final state = await container.read(aiKeySettingsViewModelProvider.future);

      expect(state.configuredProviders[AiProvider.groq], isTrue);
      expect(state.configuredProviders[AiProvider.gemini], isFalse);
      expect(state.toString(), isNot(contains('test-secret')));
    });

    test(
        'saves and removes a key for the selected provider with current user ID',
        () async {
      await container.read(aiKeySettingsViewModelProvider.future);
      final viewModel =
          container.read(aiKeySettingsViewModelProvider.notifier);

      viewModel.selectProvider(AiProvider.openRouter);
      expect(await viewModel.saveKey('openrouter-secret'), isTrue);
      expect(storage.keys[(userId, AiProvider.openRouter)], 'openrouter-secret');
      expect(
        container
            .read(aiKeySettingsViewModelProvider)
            .requireValue
            .selectedProviderIsConfigured,
        isTrue,
      );

      expect(await viewModel.removeKey(), isTrue);
      expect(
        storage.keys.containsKey((userId, AiProvider.openRouter)),
        isFalse,
      );
      expect(
        container
            .read(aiKeySettingsViewModelProvider)
            .requireValue
            .selectedProviderIsConfigured,
        isFalse,
      );
    });

    test('reloads when the signed-in user changes', () async {
      const userA = 'user-aaa';
      const userB = 'user-bbb';

      storage.keys[(userA, AiProvider.gemini)] = 'secret-a';
      storage.keys[(userB, AiProvider.groq)] = 'secret-b';

      final dynamicContainer = ProviderContainer(
        overrides: [
          aiApiKeyStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(dynamicContainer.dispose);

      // Initially user A
      dynamicContainer.read(currentUserIdProvider.notifier).state = userA;
      final stateA =
          await dynamicContainer.read(aiKeySettingsViewModelProvider.future);
      expect(stateA.configuredProviders[AiProvider.gemini], isTrue);
      expect(stateA.configuredProviders[AiProvider.groq], isFalse);

      // User switches to user B
      dynamicContainer.read(currentUserIdProvider.notifier).state = userB;
      final stateB =
          await dynamicContainer.read(aiKeySettingsViewModelProvider.future);
      expect(stateB.configuredProviders[AiProvider.gemini], isFalse);
      expect(stateB.configuredProviders[AiProvider.groq], isTrue);
    });

    test('returns empty state when no user is signed in', () async {
      final noUserContainer = ProviderContainer(
        overrides: [
          aiApiKeyStorageServiceProvider.overrideWithValue(storage),
          currentUserIdProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(noUserContainer.dispose);

      final state =
          await noUserContainer.read(aiKeySettingsViewModelProvider.future);

      expect(state.configuredProviders, isEmpty);
    });

    test('deleteAllKeys deletes all keys for current user on sign out', () async {
      storage.keys[(userId, AiProvider.gemini)] = 'g-secret';
      storage.keys[(userId, AiProvider.groq)] = 'q-secret';
      storage.keys[('other-user', AiProvider.gemini)] = 'other-secret';

      await container.read(aiKeySettingsViewModelProvider.future);
      final viewModel =
          container.read(aiKeySettingsViewModelProvider.notifier);

      await viewModel.deleteAllKeys();

      expect(storage.deletedAllForUsers, contains(userId));
      expect(storage.keys.containsKey((userId, AiProvider.gemini)), isFalse);
      expect(storage.keys[('other-user', AiProvider.gemini)], 'other-secret');
    });
  });
}

class _FakeAiApiKeyStorageService implements AiApiKeyStorageService {
  final Map<(String, AiProvider), String> keys = {};
  final List<String> deletedAllForUsers = [];

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
    deletedAllForUsers.add(userId);
    keys.removeWhere((key, _) => key.$1 == userId);
  }
}