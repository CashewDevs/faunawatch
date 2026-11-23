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
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

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
      throw ArgumentError('API key must not be empty.');
    }
    return _storage.write(provider.storageKey(userId), normalizedKey);
  }

  @override
  Future<void> deleteKey(String userId, AiProvider provider) =>
      _storage.delete(provider.storageKey(userId));

  /// Also deletes the backup key ([AiBackupKeyStorageService]).
  @override
  Future<void> deleteAllKeys(String userId) async {
    for (final provider in AiProvider.values) {
      await _storage.delete(provider.storageKey(userId));
    }
    await _storage.delete(_backupKeyStorageKey(userId));
    await _storage.delete(_backupProviderStorageKey(userId));
  }
}

final aiApiKeyStorageServiceProvider = Provider<AiApiKeyStorageService>(
  (ref) => SecureAiApiKeyStorageService(),
);

// The backup key lives beside the per-provider keys, under its own name, so
// it can be a second key for the same provider as the main one.
String _backupKeyStorageKey(String userId) =>
    'faunawatch.ai_key.$userId.backup';
String _backupProviderStorageKey(String userId) =>
    'faunawatch.ai_key.$userId.backup_provider';

/// The one optional backup key: any provider (even a second key for the main
/// provider), tried when the main key is rejected, out of quota, or its
/// provider is down. Stored in the same secure store as the main keys.
abstract interface class AiBackupKeyStorageService {
  /// The backup's provider, or null when no backup key is saved.
  Future<AiProvider?> readProvider(String userId);

  /// The backup key. Only services read it; it never reaches a view.
  Future<String?> readKey(String userId);

  /// Saves [apiKey] for [provider] as the backup, replacing any earlier one.
  Future<void> save(String userId, AiProvider provider, String apiKey);

  Future<void> delete(String userId);
}

final class SecureAiBackupKeyStorageService
    implements AiBackupKeyStorageService {
  SecureAiBackupKeyStorageService({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

  @override
  Future<AiProvider?> readProvider(String userId) async {
    final key = await readKey(userId);
    if (key == null || key.isEmpty) return null;
    return AiProvider.tryParse(
      await _storage.read(_backupProviderStorageKey(userId)),
    );
  }

  @override
  Future<String?> readKey(String userId) =>
      _storage.read(_backupKeyStorageKey(userId));

  @override
  Future<void> save(String userId, AiProvider provider, String apiKey) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError('API key must not be empty.');
    }
    await _storage.write(_backupProviderStorageKey(userId), provider.name);
    await _storage.write(_backupKeyStorageKey(userId), normalizedKey);
  }

  @override
  Future<void> delete(String userId) async {
    await _storage.delete(_backupKeyStorageKey(userId));
    await _storage.delete(_backupProviderStorageKey(userId));
  }
}

final aiBackupKeyStorageServiceProvider = Provider<AiBackupKeyStorageService>(
  (ref) => SecureAiBackupKeyStorageService(),
);
