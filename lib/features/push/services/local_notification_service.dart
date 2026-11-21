import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Id of the high-importance Android channel. Must match the AndroidManifest
/// `default_notification_channel_id` meta-data and the `send-push` function.
const androidChannelId = 'faunawatch_default';

/// Shows a system banner for a push that arrives while the app is open
/// (Android only; iOS presents foreground pushes itself).
abstract interface class LocalNotificationService {
  /// False when local notifications are not available (no-op service).
  bool get isAvailable;

  /// Posts a heads-up notification. A later call with the same [tag] replaces
  /// the earlier banner. [data] is handed back by [onTap] / [getLaunchData].
  Future<void> show({
    required String title,
    required String body,
    required String tag,
    required Map<String, String> data,
  });

  /// The `data` of each local notification the user taps.
  Stream<Map<String, dynamic>> get onTap;

  /// The `data` of the local notification that launched the app (null if
  /// none).
  Future<Map<String, dynamic>?> getLaunchData();
}

/// Used on unsupported platforms and in tests.
class NoopLocalNotificationService implements LocalNotificationService {
  const NoopLocalNotificationService();

  @override
  bool get isAvailable => false;
  @override
  Future<void> show({
    required String title,
    required String body,
    required String tag,
    required Map<String, String> data,
  }) async {}
  @override
  Stream<Map<String, dynamic>> get onTap => const Stream.empty();
  @override
  Future<Map<String, dynamic>?> getLaunchData() async => null;
}

/// [LocalNotificationService] on `flutter_local_notifications`. Create it only
/// through [initializeLocalNotifications].
class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<Map<String, dynamic>> _taps =
      StreamController.broadcast();

  static const _channel = AndroidNotificationChannel(
    androidChannelId,
    'Notifications',
    description: 'Reports, comments, likes and messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final data = decodePayload(response.payload);
        if (data != null) _taps.add(data);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  @override
  bool get isAvailable => true;

  @override
  Future<void> show({
    required String title,
    required String body,
    required String tag,
    required Map<String, String> data,
  }) {
    return _plugin.show(
      // The tag identifies the banner, so one id is enough; it is also the id
      // FCM uses, so a pushed banner and a local one replace each other.
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  @override
  Stream<Map<String, dynamic>> get onTap => _taps.stream;

  @override
  Future<Map<String, dynamic>?> getLaunchData() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return decodePayload(details.notificationResponse?.payload);
  }

  /// Parses a notification payload written by [show]; null if it is not ours.
  @visibleForTesting
  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

/// Creates the Android channel (before any push can arrive) and returns the
/// service. Never throws: on iOS, web or any failure it returns
/// [NoopLocalNotificationService].
Future<LocalNotificationService> initializeLocalNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopLocalNotificationService();
  }
  try {
    final service = FlutterLocalNotificationService(
      FlutterLocalNotificationsPlugin(),
    );
    await service._init();
    return service;
  } catch (_) {
    return const NoopLocalNotificationService();
  }
}

/// The local notification service. `main` overrides it with the result of
/// [initializeLocalNotifications]; the default is the no-op service.
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => const NoopLocalNotificationService(),
);
