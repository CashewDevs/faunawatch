import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:faunawatch/features/settings/services/ai_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryStore store;
  late SecureAiPreferencesService service;

  setUp(() {
    store = _MemoryStore();
    service = SecureAiPreferencesService(storage: store);
  });

  test('nothing saved loads as no choice', () async {
    final preferences = await service.load('user-a');
    expect(preferences.provider, isNull);
    expect(preferences.models, isEmpty);
  });

  test('saves and loads the provider and models per user', () async {
    await service.save(
      'user-a',
      const AiPreferences(
        provider: AiProvider.groq,
        models: {AiProvider.groq: 'qwen/qwen3.8-27b'},
      ),
    );

    final loaded = await service.load('user-a');
    expect(loaded.provider, AiProvider.groq);
    expect(loaded.models, {AiProvider.groq: 'qwen/qwen3.8-27b'});
    expect((await service.load('user-b')).provider, isNull);
    expect(store.values.keys, everyElement(startsWith('faunawatch.ai_pref.')));
  });

  test('saving removes cleared choices', () async {
    await service.save(
      'user-a',
      const AiPreferences(
        provider: AiProvider.gemini,
        models: {AiProvider.gemini: 'g'},
      ),
    );
    await service.save('user-a', const AiPreferences());

    expect(store.values, isEmpty);
  });

  test('an unknown stored provider is ignored', () async {
    store.values['faunawatch.ai_pref.user-a.provider'] = 'retired';
    expect((await service.load('user-a')).provider, isNull);
  });
}

class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
