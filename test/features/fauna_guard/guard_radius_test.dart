import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_proximity.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_radius.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GuardLocation centre(double latitude, double longitude) => GuardLocation(
    latitude: latitude,
    longitude: longitude,
    accuracy: 0,
    timestamp: DateTime(2026),
  );

  test('every ring point is the alert distance from the report', () {
    for (final (latitude, longitude) in const [(10.3, 123.9), (60.0, -20.0)]) {
      for (final radius in const [500.0, 1000.0]) {
        final points = circlePoints(latitude, longitude, radius);
        expect(points, hasLength(65));
        expect(points.last, points.first);
        for (final point in points) {
          expect(
            centre(latitude, longitude).distanceTo(point[1], point[0]),
            closeTo(radius, 2),
          );
        }
      }
    }
  });

  test('each valid report gets a 1 km and a 500 m ring; bad ones none', () {
    final rings = guardRadiusRings(const [
      CommunityReport(
        id: 'ok',
        category: 'animal_in_need',
        latitude: 10.3,
        longitude: 123.9,
        description: 'Bird',
      ),
      CommunityReport(
        id: 'bad',
        category: 'animal_in_need',
        latitude: 95,
        longitude: 123.9,
        description: 'Bird',
      ),
    ]);

    expect(rings.map((ring) => ring.proximity), [
      GuardProximity.gettingCloser,
      GuardProximity.nearby,
    ]);
    final outer = rings.first.points.first;
    final inner = rings.last.points.first;
    expect(
      centre(10.3, 123.9).distanceTo(outer[1], outer[0]),
      closeTo(1000, 2),
    );
    expect(centre(10.3, 123.9).distanceTo(inner[1], inner[0]), closeTo(500, 2));
  });
}
