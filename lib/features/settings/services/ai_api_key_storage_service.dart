import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Deletes all entries whose key starts with [prefix].
  Future<void> deleteAllWithPrefix(String prefix);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAllWithPrefix(String prefix) async {
    final allEntries = await _storage.readAll();
    for (final key in allEntries.keys) {
      if (key.startsWith(prefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}

abstract interface class AiApiKeyStorageService {
  Future<String?> readKey(String userId, AiProvider provider);
  Future<void> saveKey(String userId, AiProvider provider, String apiKey);
  Future<void> deleteKey(String userId, AiProvider provider);

  /// Deletes all stored AI provider keys for [userId].
  Future<void> deleteAllKeys(String userId);
}

final class SecureAiApiKeyStorageService implements AiApiKeyStorageService {
  SecureAiApiKeyStorageService({SecureKeyValueStore? storage})
      : _storage = storage ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

  @override
  Future<String?> readKey(String userId, AiProvider provider) =>
      _storage.read(provider.storageKey(userId));

  @override
  Future<void> saveKey(String userId, AiProvider provider, String apiKey) {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }
    return _storage.write(
      provider.storageKey(userId),
      normalizedKey,
    );
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) =>
      _storage.delete(provider.storageKey(userId));

  @override
  Future<void> deleteAllKeys(String userId) async {
    await _storage.deleteAllWithPrefix(AiProviderDetails.storageKeyPrefix(userId));
    for (final provider in AiProvider.values) {
      await _storage.delete(provider.storageKey(userId));
    }
  }
}

final aiApiKeyStorageServiceProvider = Provider<AiApiKeyStorageService>(
  (ref) => SecureAiApiKeyStorageService(),
);