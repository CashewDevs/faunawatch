import 'package:faunawatch/features/app_update/models/app_version.dart';

/// What the automatic update check remembers on this device between app
/// launches: when GitHub was last asked, the newest version it reported, and
/// the version whose banner the user closed.
final class UpdateReminder {
  const UpdateReminder({this.lastCheckedAt, this.lastFound, this.dismissed});

  /// GitHub is asked at most this often by the automatic check.
  static const checkInterval = Duration(hours: 6);

  final DateTime? lastCheckedAt;

  /// The newest release version at the last check, or null when there was
  /// no release.
  final AppVersion? lastFound;

  /// The version whose banner was closed; it is not shown again.
  final AppVersion? dismissed;

  /// Whether the automatic check should ask GitHub again at [now]. A clock
  /// set back in time also makes it due.
  bool isDue(DateTime now) {
    final last = lastCheckedAt;
    return last == null ||
        now.isBefore(last) ||
        now.difference(last) >= checkInterval;
  }

  /// The version the banner should offer to someone running [installed], or
  /// null when there is nothing newer or its banner was closed.
  AppVersion? noticeFor(AppVersion installed) {
    final found = lastFound;
    if (found == null || !found.isNewerThan(installed)) return null;
    return found == dismissed ? null : found;
  }

  UpdateReminder checkedAt(DateTime time, AppVersion? found) => UpdateReminder(
    lastCheckedAt: time,
    lastFound: found,
    dismissed: dismissed,
  );
}
