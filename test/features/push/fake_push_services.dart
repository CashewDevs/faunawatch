import 'dart:async';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/local_notification_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';

/// In-memory [PushMessagingService]: no Firebase, no network.
class FakePushMessagingService implements PushMessagingService {
  FakePushMessagingService({
    this.available = true,
    this.permissionGranted = true,
    this.token = 'token-1',
    this.initialMessage,
    this.platformName = 'android',
  });

  final String platformName;

  final bool available;
  bool permissionGranted;
  String? token;
  Map<String, dynamic>? initialMessage;
  int permissionRequests = 0;
  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> opened =
      StreamController.broadcast();
  final StreamController<ForegroundPushMessage> foreground =
      StreamController.broadcast();

  @override
  bool get isAvailable => available;
  @override
  String get platform => platformName;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
  @override
  Future<Map<String, dynamic>?> getInitialMessageData() async => initialMessage;
  @override
  Stream<Map<String, dynamic>> get onMessageOpened => opened.stream;
  @override
  Stream<ForegroundPushMessage> get onForegroundMessage => foreground.stream;
}

/// One local notification that was "shown".
class ShownNotification {
  const ShownNotification(this.title, this.body, this.tag, this.data);
  final String title;
  final String body;
  final String tag;
  final Map<String, String> data;
}

/// Records banners instead of posting them.
class FakeLocalNotificationService implements LocalNotificationService {
  FakeLocalNotificationService({this.launchData});

  Map<String, dynamic>? launchData;
  final List<ShownNotification> shown = [];
  final StreamController<Map<String, dynamic>> taps =
      StreamController.broadcast();

  @override
  bool get isAvailable => true;
  @override
  Future<void> show({
    required String title,
    required String body,
    required String tag,
    required Map<String, String> data,
  }) async => shown.add(ShownNotification(title, body, tag, data));
  @override
  Stream<Map<String, dynamic>> get onTap => taps.stream;
  @override
  Future<Map<String, dynamic>?> getLaunchData() async => launchData;
}

/// Records calls instead of calling Supabase.
class FakeDeviceTokenService implements DeviceTokenService {
  final List<String> registered = [];
  final List<String> unregistered = [];
  bool fail = false;

  @override
  Future<void> register(String token, String platform) async {
    if (fail) throw StateError('rpc failed');
    registered.add('$platform:$token');
  }

  @override
  Future<void> unregister(String token) async {
    if (fail) throw StateError('rpc failed');
    unregistered.add(token);
  }
}

class FakePushPreferencesService implements PushPreferencesService {
  FakePushPreferencesService({this.enabled = true});
  bool enabled;

  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}
