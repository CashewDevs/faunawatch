import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/services/update_reminder_service.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> delete(String key) async {
    if (fail) throw StateError('unavailable');
    values.remove(key);
  }
}

void main() {
  const v5 = AppVersion(1, 0, 0, build: 5);
  final noon = DateTime.utc(2026, 11, 23, 12);

  test('starts empty', () async {
    final reminder = await SecureUpdateReminderService(
      storage: _MemoryStore(),
    ).load();

    expect(reminder.lastCheckedAt, isNull);
    expect(reminder.lastFound, isNull);
  });

  test('saves a check and reads it back', () async {
    final store = _MemoryStore();
    final service = SecureUpdateReminderService(storage: store);

    await service.saveCheck(noon, v5);

    expect(store.values[SecureUpdateReminderService.lastFoundKey], '1.0.0+5');
    final reminder = await SecureUpdateReminderService(storage: store).load();
    expect(reminder.lastCheckedAt, noon);
    expect(reminder.lastFound, v5);
  });

  test('a check that found no release forgets the last version', () async {
    final store = _MemoryStore();
    final service = SecureUpdateReminderService(storage: store);

    await service.saveCheck(noon, v5);
    await service.saveCheck(noon, null);

    expect((await service.load()).lastFound, isNull);
  });

  test('unreadable values and a broken store read as empty', () async {
    final store = _MemoryStore()
      ..values[SecureUpdateReminderService.lastCheckedKey] = 'yesterday'
      ..values[SecureUpdateReminderService.lastFoundKey] = 'new';
    final service = SecureUpdateReminderService(storage: store);

    final reminder = await service.load();
    expect(reminder.lastCheckedAt, isNull);
    expect(reminder.lastFound, isNull);

    store.fail = true;
    expect((await service.load()).lastCheckedAt, isNull);
    await service.saveCheck(noon, v5);
  });
}
