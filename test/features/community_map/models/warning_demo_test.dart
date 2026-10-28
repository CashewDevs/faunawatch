import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';

double distanceFromPin(List<double> coordinate) {
  final lat = WarningDemo.latitude * math.pi / 180;
  final targetLat = coordinate[1] * math.pi / 180;
  final deltaLng = (coordinate[0] - WarningDemo.longitude) * math.pi / 180;
  final a =
      math.pow(math.sin((targetLat - lat) / 2), 2) +
      math.cos(lat) * math.cos(targetLat) * math.pow(math.sin(deltaLng / 2), 2);
  return 6371008.8 * 2 * math.asin(math.sqrt(a));
}

void main() {
  test('each simulated position falls in its selected zone only', () {
    for (final level in DemoWarningLevel.values) {
      final point = WarningDemo.simulatedPosition(level);
      final distance = distanceFromPin(point);
      expect(distance, closeTo(level.sampleDistanceMeters, 0.01));
      expect(distance, lessThan(level.radiusMeters));
      if (level != DemoWarningLevel.danger) {
        expect(
          distance,
          greaterThan(DemoWarningLevel.values[level.index + 1].radiusMeters),
        );
      }
      expect(point[0], greaterThan(WarningDemo.longitude));
    }
  });

  test(
    'zones are closed geographic polygons at the sample radius in Cebu City',
    () {
      for (final level in DemoWarningLevel.values) {
        final points = WarningDemo.boundary(level.radiusMeters);
        expect(points, hasLength(73));
        expect(points.first, points.last);
        for (final point in points) {
          expect(distanceFromPin(point), closeTo(level.radiusMeters, 0.01));
          expect(point[0], inInclusiveRange(123.87, 123.90));
          expect(point[1], inInclusiveRange(10.30, 10.33));
        }
      }
    },
  );
}
