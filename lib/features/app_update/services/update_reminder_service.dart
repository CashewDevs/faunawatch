import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:faunawatch/features/settings/services/ai_api_key_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saves the automatic update check's [UpdateReminder] on this device.
abstract interface class UpdateReminderService {
  /// The saved reminder; empty when nothing is saved or it cannot be read.
  Future<UpdateReminder> load();

  /// Remembers a finished check at [time] that found [found].
  Future<void> saveCheck(DateTime time, AppVersion? found);

  /// Remembers that the banner for [version] was closed.
  Future<void> saveDismissed(AppVersion version);
}

/// Keeps the reminder in the secure store already used for other local
/// settings (see `SecurePushPreferencesService`). Per device, not per account.
class SecureUpdateReminderService implements UpdateReminderService {
  SecureUpdateReminderService({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  static const lastCheckedKey = 'faunawatch.update.last_checked_at';
  static const lastFoundKey = 'faunawatch.update.last_found';
  static const dismissedKey = 'faunawatch.update.dismissed';

  final SecureKeyValueStore _storage;

  @override
  Future<UpdateReminder> load() async {
    try {
      final checked = await _storage.read(lastCheckedKey);
      final found = await _storage.read(lastFoundKey);
      final dismissed = await _storage.read(dismissedKey);
      return UpdateReminder(
        lastCheckedAt: checked == null ? null : DateTime.tryParse(checked),
        lastFound: found == null ? null : AppVersion.tryParse(found),
        dismissed: dismissed == null ? null : AppVersion.tryParse(dismissed),
      );
    } catch (_) {
      return const UpdateReminder();
    }
  }

  @override
  Future<void> saveCheck(DateTime time, AppVersion? found) async {
    try {
      await _storage.write(lastCheckedKey, time.toUtc().toIso8601String());
      if (found == null) {
        await _storage.delete(lastFoundKey);
      } else {
        await _storage.write(lastFoundKey, found.toString());
      }
    } catch (_) {
      // The next launch then simply checks again.
    }
  }

  @override
  Future<void> saveDismissed(AppVersion version) async {
    try {
      await _storage.write(dismissedKey, version.toString());
    } catch (_) {
      // The banner then comes back after a restart.
    }
  }
}

final updateReminderServiceProvider = Provider<UpdateReminderService>(
  (ref) => SecureUpdateReminderService(),
);
