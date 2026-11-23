import 'package:faunawatch/features/suspension/models/account_suspension.dart'
    show formatSuspensionDate;

/// How long the user has to change their mind. Set by the database
/// (`request_account_deletion()`); shown in the app's wording.
const accountDeletionGraceDays = 7;

/// The word the user types to confirm.
const accountDeletionConfirmWord = 'Delete';

/// True when [text] is the confirmation word. Capital letters and spaces
/// around it don't matter, like in the database.
bool isDeleteConfirmation(String text) =>
    text.trim().toLowerCase() == accountDeletionConfirmWord.toLowerCase();

/// The signed-in user's account is waiting to be deleted.
class AccountDeletion {
  const AccountDeletion({required this.deleteAfter});

  /// When the account is deleted for good.
  final DateTime deleteAfter;

  /// The date has passed: the account can no longer be kept, and the
  /// clean-up job deletes it shortly.
  bool isDue(DateTime now) => !now.isBefore(deleteAfter);

  /// "1 Dec 2026, 3:40 PM".
  String get deleteAfterLabel => formatSuspensionDate(deleteAfter);

  @override
  bool operator ==(Object other) =>
      other is AccountDeletion && other.deleteAfter == deleteAfter;

  @override
  int get hashCode => deleteAfter.hashCode;
}

/// Why asking to delete, or keeping, the account failed.
enum AccountDeletionFailure {
  notConfirmed('Type $accountDeletionConfirmWord to confirm.'),
  adminAccount("Admin accounts can't be deleted from the app."),
  tooLate(
    "The $accountDeletionGraceDays days have passed, so this account can't "
    'be kept.',
  ),
  unknown('Something went wrong. Check your connection and try again.');

  const AccountDeletionFailure(this.message);

  /// Shown to the user.
  final String message;
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.failure);
  final AccountDeletionFailure failure;

  @override
  String toString() => 'AccountDeletionException(${failure.name})';
}
