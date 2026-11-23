import 'package:faunawatch/features/app_update/models/app_version.dart';

/// What the automatic update check remembers on this device between app
/// launches: when GitHub was last asked and the newest version it reported.
final class UpdateReminder {
  const UpdateReminder({this.lastCheckedAt, this.lastFound});

  /// GitHub is asked at most this often by the automatic check.
  static const checkInterval = Duration(hours: 6);

  final DateTime? lastCheckedAt;

  /// The newest release version at the last check, or null when there was
  /// no release.
  final AppVersion? lastFound;

  /// Whether the automatic check should ask GitHub again at [now]. A clock
  /// set back in time also makes it due.
  bool isDue(DateTime now) {
    final last = lastCheckedAt;
    return last == null ||
        now.isBefore(last) ||
        now.difference(last) >= checkInterval;
  }

  /// The version the banner should offer to someone running [installed], or
  /// null when there is nothing newer.
  AppVersion? noticeFor(AppVersion installed) {
    final found = lastFound;
    return found != null && found.isNewerThan(installed) ? found : null;
  }
}
