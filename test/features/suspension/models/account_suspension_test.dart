import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import '../fake_suspension_service.dart';

void main() {
  group('fromRow', () {
    test('reads a my_active_suspension() row', () {
      final suspension = AccountSuspension.fromRow({
        'id': 'abc',
        'category': 'hate_or_threats',
        'level': 'locked',
        'reason': '  Threats in comments  ',
        'created_at': '2026-11-23T11:40:00+00:00',
        'ends_at': '2026-11-30T11:40:00+00:00',
      })!;

      expect(suspension.id, 'abc');
      expect(suspension.category, SuspensionCategory.hateOrThreats);
      expect(suspension.reasonLabel, 'Hate speech or threats');
      expect(suspension.isLocked, isTrue);
      expect(suspension.message, 'Threats in comments');
      expect(suspension.endsAt, DateTime.utc(2026, 11, 30, 11, 40).toLocal());
    });

    test('older suspensions: no category, restricted, no end', () {
      final suspension = AccountSuspension.fromRow({
        'id': 'old',
        'category': null,
        'level': null,
        'reason': 'Old reason',
        'created_at': '2026-11-01T00:00:00Z',
        'ends_at': null,
      })!;

      expect(suspension.category, isNull);
      expect(suspension.reasonLabel, 'Account suspended');
      expect(suspension.level, SuspensionLevel.restricted);
      expect(suspension.endsAt, isNull);
    });

    test('a row without id or start is ignored', () {
      expect(AccountSuspension.fromRow({'created_at': '2026-11-01'}), isNull);
      expect(AccountSuspension.fromRow({'id': 'x'}), isNull);
    });
  });

  test('every category maps from its database value', () {
    for (final category in SuspensionCategory.values) {
      expect(SuspensionCategory.fromDb(category.dbValue), category);
    }
    expect(SuspensionCategory.fromDb('nope'), isNull);
  });

  test('dates read like "30 Nov 2026, 7:40 PM"', () {
    expect(
      formatSuspensionDate(DateTime(2026, 11, 30, 19, 40)),
      '30 Nov 2026, 7:40 PM',
    );
    expect(
      formatSuspensionDate(DateTime(2026, 1, 2, 0, 5)),
      '2 Jan 2026, 12:05 AM',
    );
    expect(
      formatSuspensionDate(DateTime(2026, 6, 9, 12)),
      '9 Jun 2026, 12:00 PM',
    );
  });

  test('blocked messages say what and until when', () {
    expect(
      restrictedFor7Days().blockedMessage(SuspendedAction.like),
      "You can't like posts while your account is suspended "
      '(until 30 Nov 2026, 7:40 PM).',
    );
    expect(
      lockedUntilLifted().blockedMessage(SuspendedAction.message),
      "You can't send messages while your account is suspended "
      '(until an admin lifts it).',
    );
  });
}
