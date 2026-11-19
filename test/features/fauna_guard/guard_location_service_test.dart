import 'package:faunawatch/features/fauna_guard/models/fauna_guard_state.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

void main() {
  late _Platform platform;
  setUp(() => platform = _Platform());
  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'configures continuous background updates for $target and cancels native stream',
      () async {
        final service = DeviceGuardLocationService(
          platform: platform,
          target: target,
          isWeb: false,
        );
        await service.requestAccess();
        final subscription = service.watch().listen((_) {});
        expect(platform.settings!.distanceFilter, 10);
        if (target == TargetPlatform.android) {
          final settings = platform.settings as AndroidSettings;
          expect(settings.maxUpdateAge, Duration.zero);
          expect(settings.foregroundNotificationConfig!.enableWakeLock, isTrue);
          expect(settings.foregroundNotificationConfig!.setOngoing, isTrue);
          expect(
            settings.foregroundNotificationConfig!.notificationIcon.name,
            'ic_fauna_guard',
          );
        } else {
          final settings = platform.settings as AppleSettings;
          expect(settings.allowBackgroundLocationUpdates, isTrue);
          expect(settings.showBackgroundLocationIndicator, isTrue);
          expect(settings.pauseLocationUpdatesAutomatically, isFalse);
        }
        await subscription.cancel();
      },
    );
  }
  test(
    'requests only when denied and handles disabled/permanently denied access',
    () async {
      final service = DeviceGuardLocationService(
        platform: platform,
        target: TargetPlatform.android,
        isWeb: false,
      );
      platform.permission = LocationPermission.denied;
      await service.requestAccess();
      expect(platform.requests, 1);
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        service.requestAccess(),
        throwsA(
          isA<GuardException>().having(
            (e) => e.failure,
            'failure',
            GuardFailure.permissionPermanentlyDenied,
          ),
        ),
      );
      expect(platform.requests, 1);
      platform.enabled = false;
      await expectLater(
        service.requestAccess(),
        throwsA(
          isA<GuardException>().having(
            (e) => e.failure,
            'failure',
            GuardFailure.locationDisabled,
          ),
        ),
      );
    },
  );
  test('web preview fails gracefully before accessing GPS', () async {
    final service = DeviceGuardLocationService(
      platform: platform,
      target: TargetPlatform.android,
      isWeb: true,
    );
    await expectLater(
      service.requestAccess(),
      throwsA(
        isA<GuardException>().having(
          (e) => e.failure,
          'failure',
          GuardFailure.unsupported,
        ),
      ),
    );
    expect(platform.requests, 0);
  });
}

class _Platform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool enabled = true;
  int requests = 0;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return LocationPermission.whileInUse;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return const Stream.empty();
  }
}
