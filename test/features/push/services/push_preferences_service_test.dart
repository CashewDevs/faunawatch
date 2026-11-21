import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';

class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool fail = false;

  @override
  Future<String?> read(String key) async {
    if (fail) throw StateError('unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test('defaults to on', () async {
    final service = SecurePushPreferencesService(storage: _MemoryStore());
    expect(await service.isEnabled(), isTrue);
  });

  test('persists the choice in the secure store', () async {
    final store = _MemoryStore();
    final service = SecurePushPreferencesService(storage: store);
    await service.setEnabled(false);
    expect(store.values[SecurePushPreferencesService.storageKey], 'false');
    expect(await service.isEnabled(), isFalse);
    expect(
      await SecurePushPreferencesService(storage: store).isEnabled(),
      isFalse,
    );
    await service.setEnabled(true);
    expect(await service.isEnabled(), isTrue);
  });

  test('an unreadable store means on, and writes do not throw', () async {
    final store = _MemoryStore()..fail = true;
    final service = SecurePushPreferencesService(storage: store);
    expect(await service.isEnabled(), isTrue);
    await service.setEnabled(false);
  });
}
