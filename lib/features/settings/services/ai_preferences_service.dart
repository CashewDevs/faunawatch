import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/settings/models/ai_preferences.dart';
import 'package:faunawatch/features/settings/models/ai_provider.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

/// Saves the user's provider and model choices on this device.
abstract interface class AiPreferencesService {
  Future<AiPreferences> load(String userId);
  Future<void> save(String userId, AiPreferences preferences);
}

/// Stores choices in the same per-user secure store as the keys. They aren't
/// secret, but this keeps them out of backups and needs no extra dependency.
class SecureAiPreferencesService implements AiPreferencesService {
  SecureAiPreferencesService({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

  static String _providerKey(String userId) =>
      'faunawatch.ai_pref.$userId.provider';

  static String _modelKey(String userId, AiProvider provider) =>
      'faunawatch.ai_pref.$userId.model.${provider.name}';

  @override
  Future<AiPreferences> load(String userId) async {
    final provider = AiProvider.tryParse(
      await _storage.read(_providerKey(userId)),
    );
    final models = <AiProvider, String>{};
    for (final candidate in AiProvider.values) {
      final model = await _storage.read(_modelKey(userId, candidate));
      if (model != null && model.isNotEmpty) models[candidate] = model;
    }
    return AiPreferences(provider: provider, models: models);
  }

  @override
  Future<void> save(String userId, AiPreferences preferences) async {
    final provider = preferences.provider;
    if (provider == null) {
      await _storage.delete(_providerKey(userId));
    } else {
      await _storage.write(_providerKey(userId), provider.name);
    }
    for (final candidate in AiProvider.values) {
      final model = preferences.models[candidate];
      if (model == null) {
        await _storage.delete(_modelKey(userId, candidate));
      } else {
        await _storage.write(_modelKey(userId, candidate), model);
      }
    }
  }
}

final aiPreferencesServiceProvider = Provider<AiPreferencesService>(
  (ref) => SecureAiPreferencesService(),
);
