import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class AiApiKeyStorageService {
  Future<String?> readKey(AiProvider provider);
  Future<void> saveKey(AiProvider provider, String apiKey);
  Future<void> deleteKey(AiProvider provider);
}

final class SecureAiApiKeyStorageService implements AiApiKeyStorageService {
  SecureAiApiKeyStorageService({SecureKeyValueStore? storage})
      : _storage = storage ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

  @override
  Future<String?> readKey(AiProvider provider) =>
      _storage.read(provider.storageKey);

  @override
  Future<void> saveKey(AiProvider provider, String apiKey) {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }
    return _storage.write(provider.storageKey, normalizedKey);
  }

  @override
  Future<void> deleteKey(AiProvider provider) =>
      _storage.delete(provider.storageKey);
}

final aiApiKeyStorageServiceProvider = Provider<AiApiKeyStorageService>(
  (ref) => SecureAiApiKeyStorageService(),
);