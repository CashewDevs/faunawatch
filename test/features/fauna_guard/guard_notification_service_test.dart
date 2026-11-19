import 'package:faunawatch/features/fauna_guard/models/fauna_guard_state.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool granted = true;
  setUp(() {
    calls.clear();
    granted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'requestNotificationsPermission' ||
              call.method == 'requestPermissions') {
            return granted;
          }
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'requests permission and posts/cancels only FaunaGuard notifications on $target',
      () async {
        debugDefaultTargetPlatformOverride = target;
        if (target == TargetPlatform.android) {
          AndroidFlutterLocalNotificationsPlugin.registerWith();
        } else {
          IOSFlutterLocalNotificationsPlugin.registerWith();
        }
        final service = LocalGuardNotificationService();
        await service.clear();
        expect(calls, isEmpty);
        await service.requestAccess();
        await service.show(
          title: 'Nearby',
          body: 'Approximate report location.',
        );
        final showing = calls.firstWhere((c) => c.method == 'show');
        expect(
          showing.arguments['id'],
          LocalGuardNotificationService.notificationId,
        );
        expect(showing.arguments['body'], 'Approximate report location.');
        if (target == TargetPlatform.iOS) {
          final initialize = calls.firstWhere((c) => c.method == 'initialize');
          expect(initialize.arguments['requestAlertPermission'], isFalse);
        }
        await service.clear();
        expect(calls.last.method, 'cancel');
        expect(
          target == TargetPlatform.iOS
              ? calls.last.arguments
              : calls.last.arguments['id'],
          LocalGuardNotificationService.notificationId,
        );
      },
    );
  }
  test('denied notification permission prevents opt-in', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    granted = false;
    await expectLater(
      LocalGuardNotificationService().requestAccess(),
      throwsA(
        isA<GuardException>().having(
          (e) => e.failure,
          'failure',
          GuardFailure.notificationsDenied,
        ),
      ),
    );
    expect(calls.where((c) => c.method == 'show'), isEmpty);
  });
}
