import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/account_deletion/models/account_deletion.dart';

void main() {
  group('isDeleteConfirmation', () {
    test('accepts Delete in any case, with spaces around it', () {
      expect(isDeleteConfirmation('Delete'), isTrue);
      expect(isDeleteConfirmation('delete'), isTrue);
      expect(isDeleteConfirmation('  DELETE '), isTrue);
    });

    test('refuses anything else', () {
      expect(isDeleteConfirmation(''), isFalse);
      expect(isDeleteConfirmation('Delet'), isFalse);
      expect(isDeleteConfirmation('Delete!'), isFalse);
      expect(isDeleteConfirmation('De lete'), isFalse);
    });
  });

  group('AccountDeletion', () {
    final deletion = AccountDeletion(
      deleteAfter: DateTime(2026, 12, 1, 15, 40),
    );

    test('is due from the delete date on', () {
      expect(deletion.isDue(DateTime(2026, 12, 1, 15, 39)), isFalse);
      expect(deletion.isDue(DateTime(2026, 12, 1, 15, 40)), isTrue);
      expect(deletion.isDue(DateTime(2026, 12, 2)), isTrue);
    });

    test('shows the date and time', () {
      expect(deletion.deleteAfterLabel, '1 Dec 2026, 3:40 PM');
    });

    test('equal when the date is the same', () {
      expect(
        deletion,
        AccountDeletion(deleteAfter: DateTime(2026, 12, 1, 15, 40)),
      );
    });
  });

  test('every failure has a message', () {
    for (final failure in AccountDeletionFailure.values) {
      expect(failure.message, isNotEmpty);
    }
    expect(
      AccountDeletionFailure.notConfirmed.message,
      'Type Delete to confirm.',
    );
  });
}
