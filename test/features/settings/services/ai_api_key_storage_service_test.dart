import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

void main() {
  group('SecureAiApiKeyStorageService', () {
    late _MemorySecureKeyValueStore storage;
    late SecureAiApiKeyStorageService service;

    setUp(() {
      storage = _MemorySecureKeyValueStore();
      service = SecureAiApiKeyStorageService(storage: storage);
    });

    test('stores each provider key independently and trims whitespace', () async {
      await service.saveKey(AiProvider.gemini, '  gemini-secret  ');
      await service.saveKey(AiProvider.groq, 'groq-secret');

      expect(await service.readKey(AiProvider.gemini), 'gemini-secret');
      expect(await service.readKey(AiProvider.groq), 'groq-secret');
      expect(await service.readKey(AiProvider.openRouter), isNull);
    });

    test('rejects an empty key', () async {
      await expectLater(
        service.saveKey(AiProvider.gemini, '  '),
        throwsArgumentError,
      );
      expect(storage.values, isEmpty);
    });

    test('deletes only the selected provider key', () async {
      await service.saveKey(AiProvider.gemini, 'gemini-secret');
      await service.saveKey(AiProvider.groq, 'groq-secret');

      await service.deleteKey(AiProvider.gemini);

      expect(await service.readKey(AiProvider.gemini), isNull);
      expect(await service.readKey(AiProvider.groq), 'groq-secret');
    });
  });
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}