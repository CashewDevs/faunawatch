import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// The `data` of a push message, as sent by the `send-push` Edge Function.
///
/// All values are strings in FCM; empty values are treated as missing.
class PushPayload {
  const PushPayload({
    required this.notificationId,
    this.type,
    this.reportId,
    this.threadId,
  });

  /// Reads FCM message data. Returns null when there is no notification id
  /// (the message was not sent by FaunaWatch), so it is ignored.
  static PushPayload? fromData(Map<String, dynamic> data) {
    String? read(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final id = read('notification_id');
    if (id == null) return null;
    return PushPayload(
      notificationId: id,
      type: read('type'),
      reportId: read('report_id'),
      threadId: read('thread_id'),
    );
  }

  final String notificationId;

  /// The database `notification_type` value.
  final String? type;
  final String? reportId;
  final String? threadId;

  /// The same grouping key the `send-push` function uses as the Android tag
  /// (`groupKey` in its logic.ts), so a grouped update replaces the previous
  /// banner.
  String get groupKey {
    final String key;
    if (threadId != null) {
      key = 'chat-$threadId';
    } else if (reportId != null) {
      key = 'report-$reportId-${type ?? 'other'}';
    } else {
      key = 'n-$notificationId';
    }
    return key.length > 64 ? key.substring(0, 64) : key;
  }

  /// A notification with only what tapping needs, so the existing
  /// [notificationTargetFor] rules decide where to go.
  NotificationItem toNotificationItem() => NotificationItem(
    id: notificationId,
    title: '',
    message: '',
    timestamp: '',
    isUnread: true,
    type: notificationTypeFromDb(type),
    reportId: reportId,
    threadId: threadId,
  );

  /// Where tapping the push leads, or null when it only opens the app.
  NotificationTarget? get target => notificationTargetFor(toNotificationItem());
}
