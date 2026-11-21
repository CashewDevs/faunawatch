import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

/// Contract for the per-device "push notifications" choice (not per account).
abstract interface class PushPreferencesService {
  /// Whether push is on for this device. On by default, and also when the
  /// stored value cannot be read.
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
}

/// Keeps the choice in the secure store already used for other local settings.
class SecurePushPreferencesService implements PushPreferencesService {
  SecurePushPreferencesService({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  static const storageKey = 'faunawatch.push.enabled';

  final SecureKeyValueStore _storage;

  @override
  Future<bool> isEnabled() async {
    try {
      return await _storage.read(storageKey) != 'false';
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _storage.write(storageKey, enabled ? 'true' : 'false');
    } catch (_) {
      /* The choice then only lasts until the app restarts. */
    }
  }
}

/// Provider exposing [PushPreferencesService].
final pushPreferencesServiceProvider = Provider<PushPreferencesService>(
  (ref) => SecurePushPreferencesService(),
);
