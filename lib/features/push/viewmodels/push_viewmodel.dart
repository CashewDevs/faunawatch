import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/push/models/push_payload.dart';
import 'package:faunawatch/features/push/services/device_token_service.dart';
import 'package:faunawatch/features/push/services/local_notification_service.dart';
import 'package:faunawatch/features/push/services/push_messaging_service.dart';
import 'package:faunawatch/features/push/services/push_preferences_service.dart';

/// Presentation state for push notifications.
class PushState {
  const PushState({this.enabled = true, this.pendingTarget});

  /// The per-device "push notifications" choice (the Settings switch).
  final bool enabled;

  /// Where a tapped push should lead, until the shell has navigated there
  /// (see [PushViewModel.consumePendingTarget]).
  final NotificationTarget? pendingTarget;

  PushState copyWith({
    bool? enabled,
    NotificationTarget? pendingTarget,
    bool clearPendingTarget = false,
  }) {
    return PushState(
      enabled: enabled ?? this.enabled,
      pendingTarget: clearPendingTarget
          ? null
          : pendingTarget ?? this.pendingTarget,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PushState &&
      other.enabled == enabled &&
      other.pendingTarget == pendingTarget;

  @override
  int get hashCode => Object.hash(enabled, pendingTarget);
}

/// Registers this device for push while a user is signed in and push is on,
/// and turns a tapped push into a navigation target.
///
/// Does nothing when Firebase is not configured (the no-op service). Failures
/// are swallowed: push must never break the app, and nothing sensitive (tokens,
/// message contents) is logged or put in errors.
class PushViewModel extends Notifier<PushState> {
  late PushMessagingService _push;
  String? _userId;
  String? _registeredToken;
  PushPayload? _pendingPayload;
  bool _disposed = false;

  @override
  PushState build() {
    _push = ref.watch(pushMessagingServiceProvider);
    _disposed = false;
    final subscriptions = <StreamSubscription<Object?>>[];
    ref.onDispose(() {
      _disposed = true;
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
    Future.microtask(() => _start(subscriptions));
    return const PushState();
  }

  Future<void> _start(List<StreamSubscription<Object?>> subscriptions) async {
    final enabled = await ref.read(pushPreferencesServiceProvider).isEnabled();
    if (_disposed) return;
    state = state.copyWith(enabled: enabled);
    if (!_push.isAvailable) return;

    final local = ref.read(localNotificationServiceProvider);
    subscriptions
      ..add(_push.onTokenRefresh.listen(_onTokenRefresh, onError: (_) {}))
      ..add(_push.onMessageOpened.listen(_onMessageOpened, onError: (_) {}))
      ..add(_push.onForegroundMessage.listen(_onForeground, onError: (_) {}))
      ..add(local.onTap.listen(_onMessageOpened, onError: (_) {}));
    ref.listen<AsyncValue<String?>>(
      currentUserIdProvider,
      (_, next) => _onUserChanged(next.valueOrNull),
      fireImmediately: true,
    );
    try {
      final initial = await _push.getInitialMessageData();
      if (!_disposed && initial != null) _onMessageOpened(initial);
    } catch (_) {
      /* No launch message. */
    }
    try {
      final launch = await local.getLaunchData();
      if (!_disposed && launch != null) _onMessageOpened(launch);
    } catch (_) {
      /* Not launched from a local notification. */
    }
  }

  /// A push arrived while the app is open. Android shows no banner for it, so
  /// post one (unless push is off on this device). iOS presents it itself.
  Future<void> _onForeground(ForegroundPushMessage message) async {
    if (!state.enabled || _push.platform == 'ios') return;
    final payload = PushPayload.fromData(message.data);
    if (payload == null) return;
    try {
      await ref
          .read(localNotificationServiceProvider)
          .show(
            title: message.title ?? 'FaunaWatch',
            body: message.body ?? '',
            tag: payload.groupKey,
            data: {
              for (final entry in message.data.entries)
                if (entry.value is String) entry.key: entry.value as String,
            },
          );
    } catch (_) {
      /* The in-app list still updates. */
    }
  }

  Future<void> _onUserChanged(String? userId) async {
    if (userId == _userId) return;
    final signedOut = userId == null;
    _userId = userId;
    _registeredToken = null;
    if (signedOut) {
      _pendingPayload = null;
      state = state.copyWith(clearPendingTarget: true);
      return;
    }
    unawaited(_processPendingPayload());
    await _syncRegistration();
  }

  /// Asks for permission and registers this device's token for the signed-in
  /// user, when push is on.
  Future<void> _syncRegistration() async {
    final userId = _userId;
    if (!_push.isAvailable || !state.enabled || userId == null) return;
    try {
      if (!await _push.requestPermission()) return;
      final token = await _push.getToken();
      if (token == null || _disposed || _userId != userId || !state.enabled) {
        return;
      }
      await _register(token);
    } catch (_) {
      /* Push stays off until the next sign-in or token refresh. */
    }
  }

  Future<void> _register(String token) async {
    await ref.read(deviceTokenServiceProvider).register(token, _push.platform);
    _registeredToken = token;
  }

  Future<void> _onTokenRefresh(String token) async {
    if (_userId == null || !state.enabled) return;
    try {
      await _register(token);
    } catch (_) {
      /* Retried at the next sign-in or refresh. */
    }
  }

  Future<void> _unregisterCurrent() async {
    try {
      final token = _registeredToken ?? await _push.getToken();
      if (token == null) return;
      _registeredToken = null;
      await ref.read(deviceTokenServiceProvider).unregister(token);
    } catch (_) {
      /* The server also drops tokens FCM reports as invalid. */
    }
  }

  /// The Settings switch: remembers the choice on this device, then registers
  /// (on) or unregisters (off) this device's token.
  Future<void> setEnabled(bool enabled) async {
    if (state.enabled == enabled) return;
    state = state.copyWith(enabled: enabled);
    await ref.read(pushPreferencesServiceProvider).setEnabled(enabled);
    if (!_push.isAvailable || _userId == null) return;
    if (enabled) {
      await _syncRegistration();
    } else {
      await _unregisterCurrent();
    }
  }

  /// Call before the session ends: removes this device's token while the user
  /// can still call the database.
  Future<void> onBeforeSignOut() async {
    if (!_push.isAvailable || _userId == null) return;
    await _unregisterCurrent();
  }

  /// Call when signing out failed after [onBeforeSignOut].
  Future<void> onSignOutFailed() => _syncRegistration();

  void _onMessageOpened(Map<String, dynamic> data) {
    final payload = PushPayload.fromData(data);
    if (payload == null) return;
    _pendingPayload = payload;
    unawaited(_processPendingPayload());
  }

  /// Once a user is signed in: publishes the tapped push's target and marks
  /// its notification read.
  Future<void> _processPendingPayload() async {
    final payload = _pendingPayload;
    if (payload == null || _userId == null) return;
    _pendingPayload = null;
    final target = payload.target;
    if (target != null) state = state.copyWith(pendingTarget: target);
    try {
      await ref
          .read(notificationsServiceProvider)
          .markAsRead(payload.notificationId);
    } catch (_) {
      /* The notification stays unread; the target still opens. */
    }
  }

  /// Returns the target of a tapped push and clears it. The shell calls this
  /// once it is shown, so a push that launched the app waits for the splash
  /// and sign-in.
  NotificationTarget? consumePendingTarget() {
    final target = state.pendingTarget;
    if (target != null) state = state.copyWith(clearPendingTarget: true);
    return target;
  }
}

/// Provider managing push registration and tapped-push navigation.
final pushViewModelProvider = NotifierProvider<PushViewModel, PushState>(
  PushViewModel.new,
);
