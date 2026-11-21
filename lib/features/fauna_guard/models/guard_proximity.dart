import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'guard_location.dart';

enum GuardProximity { gettingCloser, nearby }

class GuardAlert {
  const GuardAlert({required this.report, required this.proximity});

  final CommunityReport report;
  final GuardProximity proximity;
}

/// Emits each report's distance band once per opt-in session, avoiding GPS
/// jitter repeatedly notifying the user at a boundary. Starting inside 500 m
/// emits only the more relevant Nearby alert.
class GuardProximityTracker {
  static const approachingRadius = 1000.0;
  static const nearbyRadius = 500.0;
  final _notified = <String, GuardProximity>{};

  List<GuardAlert> evaluate(
    GuardLocation location,
    List<CommunityReport> reports,
  ) {
    if (!location.isValid) return const [];
    final alerts = <GuardAlert>[];
    for (final report in reports) {
      if (!report.latitude.isFinite ||
          !report.longitude.isFinite ||
          report.latitude.abs() > 90 ||
          report.longitude.abs() > 180) {
        continue;
      }
      final distance = location.distanceTo(report.latitude, report.longitude);
      final proximity = distance <= nearbyRadius
          ? GuardProximity.nearby
          : distance <= approachingRadius
          ? GuardProximity.gettingCloser
          : null;
      if (proximity == null) continue;
      final previous = _notified[report.id];
      if (previous != null && previous.index >= proximity.index) continue;
      _notified[report.id] = proximity;
      alerts.add(GuardAlert(report: report, proximity: proximity));
    }
    alerts.sort(
      (a, b) => location
          .distanceTo(a.report.latitude, a.report.longitude)
          .compareTo(
            location.distanceTo(b.report.latitude, b.report.longitude),
          ),
    );
    return alerts;
  }
}
