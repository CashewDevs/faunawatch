import 'dart:async';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_location_service.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';

const guardReport = CommunityReport(
  id: 'r1',
  category: 'animal_in_need',
  latitude: 0,
  longitude: 0,
  description: 'Reported wildlife',
);

GuardLocation guardFix(double meters, {DateTime? timestamp}) => GuardLocation(
  latitude: meters / 111194.9266,
  longitude: 0,
  accuracy: 5,
  timestamp: timestamp ?? _nextFixTime(),
);

DateTime _lastFixTime = DateTime.fromMillisecondsSinceEpoch(0);

/// Now, but always later than the previous fake fix. FaunaGuard ignores fixes
/// that are not newer than the last one, and two quick `DateTime.now()` calls
/// can return the same time (common on Windows), which made tests flaky.
DateTime _nextFixTime() {
  var now = DateTime.now();
  if (!now.isAfter(_lastFixTime)) {
    now = _lastFixTime.add(const Duration(milliseconds: 1));
  }
  return _lastFixTime = now;
}

class FakeGuardLocation implements GuardLocationService {
  final fixes = StreamController<GuardLocation>.broadcast();
  Object? failure;
  Completer<void>? permission;
  int requests = 0, watches = 0, settings = 0;
  @override
  Future<void> requestAccess() async {
    requests++;
    if (failure != null) throw failure!;
    await permission?.future;
  }

  @override
  Stream<GuardLocation> watch() {
    watches++;
    return fixes.stream;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }
}

class FakeGuardNotifications implements GuardNotificationService {
  final shown = <({String title, String body})>[];
  Object? failure;
  bool failShow = false;
  int requests = 0, clears = 0;
  @override
  Future<void> requestAccess() async {
    requests++;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    if (failShow) throw StateError('unavailable');
    shown.add((title: title, body: body));
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

class FakeGuardReports implements CommunityReportsService {
  List<CommunityReport> reports = [guardReport];
  bool fail = false;
  int loads = 0;
  Completer<List<CommunityReport>>? pending;
  @override
  Future<List<CommunityReport>> load() async {
    loads++;
    if (fail) throw StateError('offline');
    return pending?.future ?? reports;
  }
}
