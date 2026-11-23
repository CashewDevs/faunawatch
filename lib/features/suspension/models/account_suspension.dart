/// How much a suspension takes away. Matches `public.suspension_level`.
enum SuspensionLevel {
  /// Can browse, but can't post, comment, like, message or edit their
  /// profile.
  restricted,

  /// Sees only the "Account suspended" screen.
  locked;

  /// Unknown or missing values count as [restricted], the database default.
  static SuspensionLevel fromDb(Object? value) =>
      value == 'locked' ? locked : restricted;
}

/// Why the user was suspended. Matches `public.suspension_category`.
enum SuspensionCategory {
  spam('spam', 'Spam'),
  misleadingReports('misleading_reports', 'Fake or misleading reports'),
  inappropriateContent('inappropriate_content', 'Inappropriate content'),
  harassment('harassment', 'Harassment or bullying'),
  hateOrThreats('hate_or_threats', 'Hate speech or threats'),
  scamOrImpersonation('scam_or_impersonation', 'Scam or impersonation'),
  other('other', 'Other');

  const SuspensionCategory(this.dbValue, this.label);

  /// The value stored in the database.
  final String dbValue;

  /// Shown to the user.
  final String label;

  /// Null for suspensions made before categories, or an unknown value.
  static SuspensionCategory? fromDb(Object? value) {
    for (final category in values) {
      if (category.dbValue == value) return category;
    }
    return null;
  }
}

/// Things a restricted user can't do, worded to finish "You can't ...".
enum SuspendedAction {
  post('post reports'),
  like('like posts'),
  comment('comment'),
  message('send messages'),
  editProfile('edit your profile');

  const SuspendedAction(this.phrase);
  final String phrase;
}

/// The signed-in user's active suspension, from `my_active_suspension()`.
/// It never says which admin made it.
class AccountSuspension {
  const AccountSuspension({
    required this.id,
    required this.level,
    required this.message,
    required this.startedAt,
    this.category,
    this.endsAt,
  });

  /// Reads a `my_active_suspension()` row; null when it isn't usable.
  static AccountSuspension? fromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final startedAt = DateTime.tryParse('${row['created_at']}');
    if (id is! String || startedAt == null) return null;
    final endsAt = row['ends_at'];
    return AccountSuspension(
      id: id,
      category: SuspensionCategory.fromDb(row['category']),
      level: SuspensionLevel.fromDb(row['level']),
      message: (row['reason'] as String?)?.trim() ?? '',
      startedAt: startedAt.toLocal(),
      endsAt: endsAt == null ? null : DateTime.tryParse('$endsAt')?.toLocal(),
    );
  }

  final String id;

  /// Null for suspensions made before categories.
  final SuspensionCategory? category;
  final SuspensionLevel level;

  /// The admin's message to the user.
  final String message;
  final DateTime startedAt;

  /// Null = until an admin lifts the suspension.
  final DateTime? endsAt;

  bool get isLocked => level == SuspensionLevel.locked;

  /// The reason's name; older suspensions have no category.
  String get reasonLabel => category?.label ?? 'Account suspended';

  /// "until 30 Nov 2026, 7:40 PM" or "until an admin lifts it".
  String get untilPhrase {
    final end = endsAt;
    return end == null
        ? 'until an admin lifts it'
        : 'until ${formatSuspensionDate(end)}';
  }

  /// "You can't like posts while your account is suspended (until …)."
  String blockedMessage(SuspendedAction action) =>
      "You can't ${action.phrase} while your account is suspended "
      '($untilPhrase).';

  @override
  bool operator ==(Object other) =>
      other is AccountSuspension &&
      other.id == id &&
      other.category == category &&
      other.level == level &&
      other.message == message &&
      other.startedAt == startedAt &&
      other.endsAt == endsAt;

  @override
  int get hashCode =>
      Object.hash(id, category, level, message, startedAt, endsAt);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "30 Nov 2026, 7:40 PM" in the time zone of [date].
String formatSuspensionDate(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final half = date.hour < 12 ? 'AM' : 'PM';
  return '${date.day} ${_months[date.month - 1]} ${date.year}, '
      '$hour:$minute $half';
}
