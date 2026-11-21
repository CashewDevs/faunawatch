import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import '../models/fauna_guard_state.dart';
import '../models/guard_location.dart';

abstract interface class GuardLocationService {
  Future<void> requestAccess();
  Stream<GuardLocation> watch();
  Future<void> openSettings();
}

class DeviceGuardLocationService implements GuardLocationService {
  DeviceGuardLocationService({
    GeolocatorPlatform? platform,
    TargetPlatform? target,
    bool? isWeb,
  }) : _platform = platform ?? GeolocatorPlatform.instance,
       _target = target ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb;

  final GeolocatorPlatform _platform;
  final TargetPlatform _target;
  final bool _isWeb;

  @override
  Future<void> requestAccess() async {
    if (_isWeb ||
        (_target != TargetPlatform.android && _target != TargetPlatform.iOS)) {
      throw const GuardException(GuardFailure.unsupported);
    }
    if (!await _platform.isLocationServiceEnabled()) {
      throw const GuardException(GuardFailure.locationDisabled);
    }
    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GuardException(GuardFailure.permissionPermanentlyDenied);
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const GuardException(GuardFailure.permissionDenied);
    }
  }

  @override
  Stream<GuardLocation> watch() {
    final settings = _target == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            maxUpdateAge: Duration.zero,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'FaunaGuard is on',
              notificationText:
                  'Watching for nearby wildlife reports. Open the map to turn off.',
              notificationChannelName: 'FaunaGuard location',
              notificationIcon: AndroidResource(name: 'ic_fauna_guard'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
            pauseLocationUpdatesAutomatically: false,
          );
    return _platform
        .getPositionStream(locationSettings: settings)
        .map(
          (fix) => GuardLocation(
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracy: fix.accuracy,
            timestamp: fix.timestamp,
          ),
        );
  }

  @override
  Future<void> openSettings() async {
    await _platform.openAppSettings();
  }
}

final guardLocationServiceProvider = Provider<GuardLocationService>(
  (ref) => DeviceGuardLocationService(),
);
