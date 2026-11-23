import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final noon = DateTime(2026, 11, 23, 12);
  const installed = AppVersion(1, 0, 0, build: 4);
  const v5 = AppVersion(1, 0, 0, build: 5);
  const v6 = AppVersion(1, 0, 0, build: 6);

  group('UpdateReminder.isDue', () {
    test('is due when GitHub was never asked', () {
      expect(const UpdateReminder().isDue(noon), isTrue);
    });

    test('waits six hours between checks', () {
      final reminder = UpdateReminder(lastCheckedAt: noon);

      expect(
        reminder.isDue(noon.add(const Duration(hours: 5, minutes: 59))),
        isFalse,
      );
      expect(reminder.isDue(noon.add(const Duration(hours: 6))), isTrue);
    });

    test('is due when the clock was set back', () {
      final reminder = UpdateReminder(lastCheckedAt: noon);

      expect(reminder.isDue(noon.subtract(const Duration(minutes: 1))), isTrue);
    });
  });

  group('UpdateReminder.noticeFor', () {
    test('offers a newer version that was not closed', () {
      expect(const UpdateReminder(lastFound: v5).noticeFor(installed), v5);
    });

    test('offers nothing when there is nothing newer', () {
      expect(const UpdateReminder().noticeFor(installed), isNull);
      expect(
        const UpdateReminder(lastFound: installed).noticeFor(installed),
        isNull,
      );
    });

    test('does not offer a version whose banner was closed', () {
      expect(
        const UpdateReminder(lastFound: v5, dismissed: v5).noticeFor(installed),
        isNull,
      );
    });

    test('offers an even newer version after one was closed', () {
      expect(
        const UpdateReminder(lastFound: v6, dismissed: v5).noticeFor(installed),
        v6,
      );
    });
  });

  test('checkedAt keeps the closed version', () {
    final reminder = const UpdateReminder(dismissed: v5).checkedAt(noon, v6);

    expect(reminder.lastCheckedAt, noon);
    expect(reminder.lastFound, v6);
    expect(reminder.dismissed, v5);
  });
}
