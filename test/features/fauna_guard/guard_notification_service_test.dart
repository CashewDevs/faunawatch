import 'package:faunawatch/features/fauna_guard/models/fauna_guard_state.dart';
import 'package:faunawatch/features/fauna_guard/services/guard_notification_service.dart';
import 'package:faunawatch/features/push/services/local_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('enabling FaunaGuard preserves push notification taps', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final local = await initializeLocalNotifications();
    expect(local.isAvailable, isTrue);
    final taps = <Map<String, dynamic>>[];
    final subscription = local.onTap.listen(taps.add);
    addTearDown(subscription.cancel);
    final container = ProviderContainer(
      overrides: [localNotificationServiceProvider.overrideWithValue(local)],
    );
    addTearDown(container.dispose);

    final guard = container.read(guardNotificationServiceProvider);
    await guard.requestAccess();
    await guard.show(title: 'Nearby', body: 'Approximate report location.');
    await guard.clear();

    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('didReceiveNotificationResponse', {
          'notificationId': 0,
          'notificationResponseType': 0,
          'payload': '{"notification_id":"n1","type":"chat_message"}',
        }),
      ),
      (_) {},
    );
    await pumpEventQueue();

    expect(taps, [
      {'notification_id': 'n1', 'type': 'chat_message'},
    ]);
    final showing = calls.firstWhere((call) => call.method == 'show');
    expect(showing.arguments['platformSpecifics']['icon'], 'ic_fauna_guard');
  });
}
