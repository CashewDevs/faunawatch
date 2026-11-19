import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fauna_guard_state.dart';

abstract interface class GuardNotificationService {
  Future<void> requestAccess();
  Future<void> show({required String title, required String body});
  Future<void> clear();
}

class LocalGuardNotificationService implements GuardNotificationService {
  LocalGuardNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 73001;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> requestAccess() async {
    if (!_initialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_fauna_guard'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    }
    final bool granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    } else {
      throw const GuardException(GuardFailure.unsupported);
    }
    if (!granted) {
      throw const GuardException(GuardFailure.notificationsDenied);
    }
  }

  @override
  Future<void> show({required String title, required String body}) =>
      _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'fauna_guard_proximity',
            'FaunaGuard nearby reports',
            channelDescription: 'Distance alerts while FaunaGuard is enabled.',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );

  @override
  Future<void> clear() async {
    if (_initialized) await _plugin.cancel(id: notificationId);
  }
}

final guardNotificationServiceProvider = Provider<GuardNotificationService>(
  (ref) => LocalGuardNotificationService(),
);
