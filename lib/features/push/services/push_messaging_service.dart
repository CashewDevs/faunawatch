import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push received while the app is open.
class ForegroundPushMessage {
  const ForegroundPushMessage({this.title, this.body, required this.data});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Contract for the device's push channel (Firebase Cloud Messaging).
abstract interface class PushMessagingService {
  /// False when Firebase is not configured; every other member is then a
  /// harmless no-op.
  bool get isAvailable;

  /// `android` or `ios`, as stored in `device_tokens.platform`.
  String get platform;

  /// Asks the user for notification permission (Android 13+ and iOS).
  /// Returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// This device's FCM token, or null when unavailable.
  Future<String?> getToken();

  /// Emits a new token whenever FCM rotates it.
  Stream<String> get onTokenRefresh;

  /// The `data` of the push that launched the app from the terminated state
  /// (null if none). Android returns it once.
  Future<Map<String, dynamic>?> getInitialMessageData();

  /// The `data` of each push the user taps while the app is in the background.
  Stream<Map<String, dynamic>> get onMessageOpened;

  /// Each push that arrives while the app is open (FCM shows no banner then).
  Stream<ForegroundPushMessage> get onForegroundMessage;
}

/// Used when Firebase is not configured or failed to start: push is silently
/// disabled and the app works as before.
class NoopPushMessagingService implements PushMessagingService {
  const NoopPushMessagingService();

  @override
  bool get isAvailable => false;
  @override
  String get platform => 'android';
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<Map<String, dynamic>?> getInitialMessageData() async => null;
  @override
  Stream<Map<String, dynamic>> get onMessageOpened => const Stream.empty();
  @override
  Stream<ForegroundPushMessage> get onForegroundMessage => const Stream.empty();
}

/// [PushMessagingService] on `firebase_messaging`. Create it only through
/// [initializePushMessaging], after Firebase started.
class FirebasePushMessagingService implements PushMessagingService {
  FirebasePushMessagingService([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  bool get isAvailable => true;

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // firebase_messaging 17 deprecates these in favour of Firebase Installation
  // IDs for "direct send". The send-push function uses the FCM HTTP v1 API,
  // which targets the registration token, so these are still the right calls.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<Map<String, dynamic>?> getInitialMessageData() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Stream<Map<String, dynamic>> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  @override
  Stream<ForegroundPushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(
        (message) => ForegroundPushMessage(
          title: message.notification?.title,
          body: message.notification?.body,
          data: message.data,
        ),
      );

  /// iOS: let the system show the banner, sound and badge while the app is
  /// open (so no local notification is posted there). No effect on Android.
  Future<void> enableForegroundPresentation() =>
      _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
}

/// Starts Firebase and returns the push service. Never throws: when the
/// Firebase config files are missing (or Firebase cannot start for any other
/// reason) it returns [NoopPushMessagingService]. Nothing is logged.
Future<PushMessagingService> initializePushMessaging() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    final service = FirebasePushMessagingService();
    try {
      await service.enableForegroundPresentation();
    } catch (_) {
      /* Foreground banners on iOS are optional. */
    }
    return service;
  } catch (_) {
    return const NoopPushMessagingService();
  }
}

/// The push service. `main` overrides it with the result of
/// [initializePushMessaging]; the default is the no-op service.
final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => const NoopPushMessagingService(),
);
