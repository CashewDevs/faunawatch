import 'package:faunawatch/features/app_update/models/app_version.dart';
import 'package:faunawatch/features/app_update/models/update_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final noon = DateTime(2026, 11, 23, 12);
  const installed = AppVersion(1, 0, 0, build: 4);
  const v5 = AppVersion(1, 0, 0, build: 5);

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
    test('offers a newer version', () {
      expect(const UpdateReminder(lastFound: v5).noticeFor(installed), v5);
    });

    test('offers nothing when there is nothing newer', () {
      expect(const UpdateReminder().noticeFor(installed), isNull);
      expect(
        const UpdateReminder(lastFound: installed).noticeFor(installed),
        isNull,
      );
      expect(const UpdateReminder(lastFound: v5).noticeFor(v5), isNull);
    });
  });
}
