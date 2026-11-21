import 'dart:math' as math;

import 'package:faunawatch/features/community_map/models/community_report.dart';

import 'guard_proximity.dart';

/// Mean Earth radius in metres, as used by spherical distance formulas.
const _earthRadius = 6371008.8;

/// The ring drawn around one report for one FaunaGuard alert distance.
class GuardRadiusRing {
  const GuardRadiusRing({required this.proximity, required this.points});

  /// Which alert this ring belongs to: [GuardProximity.gettingCloser] is the
  /// 1 km ring and [GuardProximity.nearby] is the 500 m ring.
  final GuardProximity proximity;

  /// Closed outline as `[longitude, latitude]` pairs (the first point is
  /// repeated at the end), ready for a GeoJSON polygon.
  final List<List<double>> points;
}

/// Builds the 1 km and 500 m rings FaunaGuard shows around each report.
///
/// The radii are the same ones [GuardProximityTracker] alerts on, so the
/// rings on the map match when the notifications fire. Reports with invalid
/// coordinates are skipped, as they are by the tracker.
List<GuardRadiusRing> guardRadiusRings(
  List<CommunityReport> reports, {
  int segments = 64,
}) {
  final rings = <GuardRadiusRing>[];
  for (final report in reports) {
    if (!report.latitude.isFinite ||
        !report.longitude.isFinite ||
        report.latitude.abs() > 90 ||
        report.longitude.abs() > 180) {
      continue;
    }
    for (final (proximity, radius) in const [
      (GuardProximity.gettingCloser, GuardProximityTracker.approachingRadius),
      (GuardProximity.nearby, GuardProximityTracker.nearbyRadius),
    ]) {
      rings.add(
        GuardRadiusRing(
          proximity: proximity,
          points: circlePoints(
            report.latitude,
            report.longitude,
            radius,
            segments: segments,
          ),
        ),
      );
    }
  }
  return rings;
}

/// Points on the ground [radiusMeters] away from the centre, all the way
/// round, so the ring keeps its real size at every zoom level.
List<List<double>> circlePoints(
  double latitude,
  double longitude,
  double radiusMeters, {
  int segments = 64,
}) {
  final lat1 = latitude * math.pi / 180;
  final lon1 = longitude * math.pi / 180;
  final angular = radiusMeters / _earthRadius;
  final points = <List<double>>[];
  for (var i = 0; i < segments; i++) {
    final bearing = 2 * math.pi * i / segments;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angular) +
          math.cos(lat1) * math.sin(angular) * math.cos(bearing),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2),
        );
    points.add([lon2 * 180 / math.pi, lat2 * 180 / math.pi]);
  }
  points.add(points.first);
  return points;
}
