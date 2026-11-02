import 'package:camera/camera.dart' show XFile;
import 'package:exif/exif.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// Finds where a FaunaLens photo was taken.
abstract interface class PhotoLocationService {
  /// The device's position, or null if it is off or permission is denied.
  Future<GeoCoordinates?> currentLocation();

  /// The GPS position saved in the photo file at [path], if it has one.
  Future<GeoCoordinates?> locationInPhoto(String path);
}

/// [PhotoLocationService] implementation using device GPS and photo EXIF data.
class DevicePhotoLocationService implements PhotoLocationService {
  const DevicePhotoLocationService();

  @override
  Future<GeoCoordinates?> currentLocation() async {
    final geolocator = GeolocatorPlatform.instance;
    if (!await geolocator.isLocationServiceEnabled()) return null;

    var permission = await geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return null;
    }

    final position = await geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return GeoCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async {
    return coordinatesFromExif(await XFile(path).readAsBytes());
  }
}

/// Reads the GPS position from photo [bytes].
///
/// Returns null when there is none. Android's photo picker can blank the
/// position to 0, 0 rather than remove it, so that also counts as none.
Future<GeoCoordinates?> coordinatesFromExif(List<int> bytes) async {
  final tags = await readExifFromBytes(bytes);
  final latitude = _degrees(
    tags['GPS GPSLatitude'],
    tags['GPS GPSLatitudeRef'],
    negativeRef: 'S',
    limit: 90,
  );
  final longitude = _degrees(
    tags['GPS GPSLongitude'],
    tags['GPS GPSLongitudeRef'],
    negativeRef: 'W',
    limit: 180,
  );
  if (latitude == null || longitude == null) return null;
  if (latitude == 0 && longitude == 0) return null;
  return GeoCoordinates(latitude: latitude, longitude: longitude);
}

double? _degrees(
  IfdTag? value,
  IfdTag? ref, {
  required String negativeRef,
  required double limit,
}) {
  if (value == null) return null;
  final parts = value.values.toList().whereType<Ratio>().toList();
  if (parts.length < 3) return null;

  final degrees =
      parts[0].toDouble() +
      parts[1].toDouble() / 60 +
      parts[2].toDouble() / 3600;
  if (!degrees.isFinite || degrees > limit) return null;
  return ref?.printable.trim().toUpperCase() == negativeRef
      ? -degrees
      : degrees;
}

/// Riverpod provider exposing [PhotoLocationService].
final photoLocationServiceProvider = Provider<PhotoLocationService>((ref) {
  return const DevicePhotoLocationService();
});
