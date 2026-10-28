import 'dart:math' as math;

/// Illustrative presets only, pending confirmed production proximity rules.
enum DemoWarningLevel {
  approaching('Approaching', 900, 750),
  near('Near', 500, 350),
  danger('Danger Zone', 180, 150);

  const DemoWarningLevel(
    this.label,
    this.radiusMeters,
    this.sampleDistanceMeters,
  );

  final String label;
  final double radiusMeters;
  final double sampleDistanceMeters;
}

/// Synthetic Cebu City scenario. These coordinates do not represent a report.
abstract final class WarningDemo {
  static const latitude = 10.3157;
  static const longitude = 123.8854;
  static const zoom = 13.8;
  static const _earthRadiusMeters = 6371008.8;

  /// A destination at [distanceMeters] and [bearingDegrees] from the sample pin.
  /// Returns GeoJSON order: longitude, latitude.
  static List<double> destination(
    double distanceMeters,
    double bearingDegrees,
  ) {
    final angularDistance = distanceMeters / _earthRadiusMeters;
    final bearing = bearingDegrees * math.pi / 180;
    final lat = latitude * math.pi / 180;
    final lng = longitude * math.pi / 180;
    final targetLat = math.asin(
      math.sin(lat) * math.cos(angularDistance) +
          math.cos(lat) * math.sin(angularDistance) * math.cos(bearing),
    );
    final targetLng =
        lng +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat),
          math.cos(angularDistance) - math.sin(lat) * math.sin(targetLat),
        );
    return [targetLng * 180 / math.pi, targetLat * 180 / math.pi];
  }

  static List<List<double>> boundary(double radiusMeters) {
    final points = List.generate(
      72,
      (index) => destination(radiusMeters, index * 5),
    );
    return [...points, points.first];
  }

  static List<double> simulatedPosition(DemoWarningLevel level) =>
      destination(level.sampleDistanceMeters, 90);
}
