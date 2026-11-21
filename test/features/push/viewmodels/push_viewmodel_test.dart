import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
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
  late FakeDeviceTokenService tokens;
  late FakePushPreferencesService prefs;
  late FakeNotificationsService notifications;
  late StreamController<String?> users;
  late ProviderContainer container;

  /// Builds the ViewModel with [userId] already signed in (null = signed out).
  Future<void> start({String? userId = 'u1'}) async {
    users = StreamController<String?>();
    container = ProviderContainer(
      overrides: [
        pushMessagingServiceProvider.overrideWithValue(push),
        deviceTokenServiceProvider.overrideWithValue(tokens),
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
    users.add(userId);
    await pumpEventQueue();
  }

  PushViewModel vm() => container.read(pushViewModelProvider.notifier);
  PushState read() => container.read(pushViewModelProvider);

  setUp(() {
    push = FakePushMessagingService();
    tokens = FakeDeviceTokenService();
    prefs = FakePushPreferencesService();
    notifications = FakeNotificationsService(items: [unread('n1')]);
  });

  group('registration', () {
    test('registers the token on sign-in when enabled', () async {
      await start();
      expect(push.permissionRequests, 1);
      expect(tokens.registered, ['android:token-1']);
    });

    test('registers when the user signs in later', () async {
      await start(userId: null);
      expect(tokens.registered, isEmpty);
      users.add('u1');
      await pumpEventQueue();
      expect(tokens.registered, ['android:token-1']);
    });

    test('does not register when disabled on this device', () async {
      prefs.enabled = false;
      await start();
      expect(read().enabled, isFalse);
      expect(push.permissionRequests, 0);
      expect(tokens.registered, isEmpty);
    });

    test('does not register without permission', () async {
      push.permissionGranted = false;
      await start();
      expect(tokens.registered, isEmpty);
    });

    test('does not register while signed out', () async {
      await start(userId: null);
      expect(push.permissionRequests, 0);
      expect(tokens.registered, isEmpty);
    });

    test('a failing registration does not throw', () async {
      tokens.fail = true;
      await start();
      expect(tokens.registered, isEmpty);
    });

    test('token refresh registers the new token', () async {
      await start();
      push.refreshes.add('token-2');
      await pumpEventQueue();
      expect(tokens.registered, ['android:token-1', 'android:token-2']);
    });

    test('token refresh is ignored when disabled or signed out', () async {
      await start();
      await vm().setEnabled(false);
      push.refreshes.add('token-2');
      await pumpEventQueue();
      expect(tokens.registered, ['android:token-1']);

      await vm().setEnabled(true);
      users.add(null);
      await pumpEventQueue();
      push.refreshes.add('token-3');
      await pumpEventQueue();
      expect(tokens.registered.contains('android:token-3'), isFalse);
    });

    test('a new account on the same device registers again', () async {
      await start();
      users.add('u2');
      await pumpEventQueue();
      expect(tokens.registered, ['android:token-1', 'android:token-1']);
    });
  });

  group('unregistering', () {
    test('turning the switch off unregisters and persists', () async {
      await start();
      await vm().setEnabled(false);
      expect(tokens.unregistered, ['token-1']);
      expect(prefs.enabled, isFalse);
      expect(read().enabled, isFalse);
    });

    test('turning the switch on registers and persists', () async {
      prefs.enabled = false;
      await start();
      await vm().setEnabled(true);
      expect(tokens.registered, ['android:token-1']);
      expect(prefs.enabled, isTrue);
    });

    test('onBeforeSignOut unregisters this device', () async {
      await start();
      await vm().onBeforeSignOut();
      expect(tokens.unregistered, ['token-1']);
    });

    test('onBeforeSignOut also covers a token that was not cached', () async {
      prefs.enabled = false;
      await start();
      await vm().onBeforeSignOut();
      expect(tokens.unregistered, ['token-1']);
    });

    test('onBeforeSignOut does nothing while signed out', () async {
      await start(userId: null);
      await vm().onBeforeSignOut();
      expect(tokens.unregistered, isEmpty);
    });

    test('a failing unregister does not throw', () async {
      await start();
      tokens.fail = true;
      await vm().onBeforeSignOut();
      await vm().setEnabled(false);
    });

    test('onSignOutFailed registers again', () async {
      await start();
      await vm().onBeforeSignOut();
      await vm().onSignOutFailed();
      expect(tokens.registered, ['android:token-1', 'android:token-1']);
    });
  });

  group('tapping a push', () {
    test('a chat push marks read and targets Messages', () async {
      await start();
      push.opened.add({
        'notification_id': 'n1',
        'type': 'chat_message',
        'thread_id': 't1',
      });
      await pumpEventQueue();
      expect(read().pendingTarget, const MessagesTarget());
      expect(notifications.items.single.isUnread, isFalse);
    });

    test('a comment push targets the report with comments', () async {
      await start();
      push.opened.add({
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

    test('consumePendingTarget returns it once', () async {
      await start();
      push.opened.add({
        'notification_id': 'n1',
        'type': 'report_like',
        'report_id': 'r1',
      });
      await pumpEventQueue();
      expect(vm().consumePendingTarget(), const ReportTarget('r1'));
      expect(vm().consumePendingTarget(), isNull);
      expect(read().pendingTarget, isNull);
    });

    test('the push that launched the app waits for sign-in', () async {
      push.initialMessage = {
        'notification_id': 'n1',
        'type': 'report_status',
        'report_id': 'r1',
      };
      await start(userId: null);
      expect(read().pendingTarget, isNull);
      expect(notifications.items.single.isUnread, isTrue);

      users.add('u1');
      await pumpEventQueue();
      expect(read().pendingTarget, const ReportTarget('r1'));
      expect(notifications.items.single.isUnread, isFalse);
    });

    test('an unknown type only marks the notification read', () async {
      await start();
      push.opened.add({'notification_id': 'n1', 'type': 'nearby_alert'});
      await pumpEventQueue();
      expect(read().pendingTarget, isNull);
      expect(notifications.items.single.isUnread, isFalse);
    });

    test('messages that are not from FaunaWatch are ignored', () async {
      await start();
      push.opened.add({'other': 'x'});
      await pumpEventQueue();
      expect(read().pendingTarget, isNull);
      expect(notifications.items.single.isUnread, isTrue);
    });

    test('a failure to mark read still opens the target', () async {
      notifications.failChanges = true;
      await start();
      push.opened.add({
        'notification_id': 'n1',
        'type': 'chat_message',
        'thread_id': 't1',
      });
      await pumpEventQueue();
      expect(read().pendingTarget, const MessagesTarget());
    });

    test('signing out clears a waiting target', () async {
      await start();
      push.opened.add({'notification_id': 'n1', 'type': 'chat_message'});
      await pumpEventQueue();
      users.add(null);
      await pumpEventQueue();
      expect(read().pendingTarget, isNull);
    });
  });

  group('Firebase unavailable', () {
    setUp(() => push = FakePushMessagingService(available: false));

    test('does nothing', () async {
      await start();
      await vm().onBeforeSignOut();
      await vm().setEnabled(false);
      expect(push.permissionRequests, 0);
      expect(tokens.registered, isEmpty);
      expect(tokens.unregistered, isEmpty);
    });

    test('the choice is still remembered', () async {
      await start();
      await vm().setEnabled(false);
      expect(prefs.enabled, isFalse);
      expect(read().enabled, isFalse);
    });

    test('the default no-op service is unavailable and inert', () async {
      const service = NoopPushMessagingService();
      expect(service.isAvailable, isFalse);
      expect(await service.requestPermission(), isFalse);
      expect(await service.getToken(), isNull);
      expect(await service.getInitialMessageData(), isNull);
      expect(await service.onTokenRefresh.isEmpty, isTrue);
      expect(await service.onMessageOpened.isEmpty, isTrue);
    });
  });
}
