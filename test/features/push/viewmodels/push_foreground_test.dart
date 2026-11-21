import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/local_notification_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';
import 'package:faunawatch/features/push/viewmodels/push_viewmodel.dart';
import '../../notifications/fake_notifications_service.dart';
import '../fake_push_services.dart';

NotificationItem unread(String id) => NotificationItem(
  id: id,
  title: 't',
  message: 'm',
  timestamp: '',
  isUnread: true,
  type: NotificationType.chat,
);

void main() {
  late FakePushMessagingService push;
  late FakeLocalNotificationService local;
  late FakePushPreferencesService prefs;
  late FakeNotificationsService notifications;
  late StreamController<String?> users;
  late ProviderContainer container;

  Future<void> start() async {
    users = StreamController<String?>();
    container = ProviderContainer(
      overrides: [
        pushMessagingServiceProvider.overrideWithValue(push),
        localNotificationServiceProvider.overrideWithValue(local),
        deviceTokenServiceProvider.overrideWithValue(FakeDeviceTokenService()),
        pushPreferencesServiceProvider.overrideWithValue(prefs),
        notificationsServiceProvider.overrideWithValue(notifications),
        currentUserIdProvider.overrideWith((ref) => users.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      users.close();
    });
    container.listen(pushViewModelProvider, (_, _) {});
    users.add('u1');
    await pumpEventQueue();
  }

  PushState read() => container.read(pushViewModelProvider);

  const chatMessage = ForegroundPushMessage(
    title: 'Sam',
    body: 'Hello',
    data: {
      'notification_id': 'n1',
      'type': 'chat_message',
      'report_id': '',
      'thread_id': 't1',
    },
  );

  setUp(() {
    push = FakePushMessagingService();
    local = FakeLocalNotificationService();
    prefs = FakePushPreferencesService();
    notifications = FakeNotificationsService(items: [unread('n1')]);
  });

  group('foreground message', () {
    test('Android shows a banner with title, body, tag and payload', () async {
      await start();
      push.foreground.add(chatMessage);
      await pumpEventQueue();
      expect(local.shown, hasLength(1));
      final shown = local.shown.single;
      expect(shown.title, 'Sam');
      expect(shown.body, 'Hello');
      expect(shown.tag, 'chat-t1');
      expect(shown.data['notification_id'], 'n1');
      expect(shown.data['thread_id'], 't1');
    });

    test('a report push is tagged by report and type', () async {
      await start();
      push.foreground.add(
        const ForegroundPushMessage(
          title: 'Liked',
          body: 'b',
          data: {
            'notification_id': 'n2',
            'type': 'report_like',
            'report_id': 'r1',
          },
        ),
      );
      await pumpEventQueue();
      expect(local.shown.single.tag, 'report-r1-report_like');
    });

    test('shows nothing when push is disabled on this device', () async {
      prefs.enabled = false;
      await start();
      push.foreground.add(chatMessage);
      await pumpEventQueue();
      expect(local.shown, isEmpty);
    });

    test('shows nothing for a message that is not from FaunaWatch', () async {
      await start();
      push.foreground.add(
        const ForegroundPushMessage(title: 'x', data: {'other': 'y'}),
      );
      await pumpEventQueue();
      expect(local.shown, isEmpty);
    });

    test('iOS does not show a local notification', () async {
      push = FakePushMessagingService(platformName: 'ios');
      await start();
      push.foreground.add(chatMessage);
      await pumpEventQueue();
      expect(local.shown, isEmpty);
    });
  });

  group('tapping a local notification', () {
    test('opens the same target as tapping a push', () async {
      await start();
      push.foreground.add(chatMessage);
      await pumpEventQueue();
      local.taps.add(local.shown.single.data);
      await pumpEventQueue();
      expect(read().pendingTarget, const MessagesTarget());
      expect(notifications.items.single.isUnread, isFalse);
    });

    test('a report payload targets the report', () async {
      await start();
      local.taps.add({
        'notification_id': 'n1',
        'type': 'report_comment',
        'report_id': 'r1',
      });
      await pumpEventQueue();
      expect(
        read().pendingTarget,
        const ReportTarget('r1', showComments: true),
      );
    });

    test('the notification that launched the app is opened', () async {
      local = FakeLocalNotificationService(
        launchData: {'notification_id': 'n1', 'type': 'chat_message'},
      );
      await start();
      expect(read().pendingTarget, const MessagesTarget());
    });
  });

  test('decodePayload reads our JSON and ignores anything else', () {
    expect(FlutterLocalNotificationService.decodePayload('{"a":"b"}'), {
      'a': 'b',
    });
    expect(FlutterLocalNotificationService.decodePayload('nope'), isNull);
    expect(FlutterLocalNotificationService.decodePayload(null), isNull);
    expect(FlutterLocalNotificationService.decodePayload('[1]'), isNull);
  });
}
