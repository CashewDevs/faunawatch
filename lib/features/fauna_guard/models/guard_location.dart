import 'dart:math' as math;

/// A device fix kept only in memory for the current FaunaGuard session.
class GuardLocation {
  const GuardLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude, longitude, accuracy;
  final DateTime timestamp;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0;

  double distanceTo(double latitude, double longitude) {
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(latitude - this.latitude);
    final dLng = radians(longitude - this.longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(this.latitude)) *
            math.cos(radians(latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
