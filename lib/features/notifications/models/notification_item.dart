/// Categories for notifications in FaunaWatch.
///
/// [reportStatus], [comment], [reportLike], [chat] and [alert] come from the database
/// (`notification_type`); [sighting], [community] and [system] are older UI
/// categories. [system] is also the fallback for a type this app version does
/// not know yet.
enum NotificationType {
  sighting,
  alert,
  community,
  system,
  reportStatus,
  comment,
  reportLike,
  chat,
}

/// Filter options for notifications list.
enum NotificationsFilter { all, unread }

/// Pure domain model representing a single notification item.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isUnread = false,
    this.type = NotificationType.system,
    this.avatarAsset,
    this.createdAt,
    this.reportId,
    this.threadId,
  });

  /// Maps a `notifications` row.
  ///
  /// [timestamp] is left empty: the ViewModel formats it from [createdAt] with
  /// its own clock (see `formatNotificationAge`).
  factory NotificationItem.fromJson(Map<String, dynamic> row) {
    return NotificationItem(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      message: row['body'] as String? ?? '',
      timestamp: '',
      isUnread: row['read_at'] == null,
      type: notificationTypeFromDb(row['type'] as String?),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      reportId: row['report_id'] as String?,
      threadId: row['thread_id'] as String?,
    );
  }

  final String id;
  final String title;
  final String message;

  /// Relative label such as `5m ago`, filled in by the ViewModel.
  final String timestamp;
  final bool isUnread;
  final NotificationType type;
  final String? avatarAsset;

  /// When the notification was created (UTC from the database).
  final DateTime? createdAt;

  /// The report this is about, for `reportStatus`, `comment` and `reportLike`.
  final String? reportId;

  /// The chat conversation this is about, for `chat`.
  final String? threadId;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? timestamp,
    bool? isUnread,
    NotificationType? type,
    String? avatarAsset,
    DateTime? createdAt,
    String? reportId,
    String? threadId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isUnread: isUnread ?? this.isUnread,
      type: type ?? this.type,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      createdAt: createdAt ?? this.createdAt,
      reportId: reportId ?? this.reportId,
      threadId: threadId ?? this.threadId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationItem &&
        other.id == id &&
        other.title == title &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.isUnread == isUnread &&
        other.type == type &&
        other.avatarAsset == avatarAsset &&
        other.createdAt == createdAt &&
        other.reportId == reportId &&
        other.threadId == threadId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    message,
    timestamp,
    isUnread,
    type,
    avatarAsset,
    createdAt,
    reportId,
    threadId,
  );
}

/// Maps the database `notification_type` value to a UI category.
NotificationType notificationTypeFromDb(String? value) {
  switch (value) {
    case 'report_status':
      return NotificationType.reportStatus;
    case 'report_comment':
      return NotificationType.comment;
    case 'report_like':
      return NotificationType.reportLike;
    case 'chat_message':
      return NotificationType.chat;
    case 'nearby_alert':
      return NotificationType.alert;
    default:
      return NotificationType.system;
  }
}

/// Where tapping a notification leads. Decided by the ViewModel; the View
/// navigates.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// Open one of the user's reports by id. [showComments] is set for comment
/// notifications, so the comments are shown straight away.
class ReportTarget extends NotificationTarget {
  const ReportTarget(this.reportId, {this.showComments = false});
  final String reportId;
  final bool showComments;

  @override
  bool operator ==(Object other) =>
      other is ReportTarget &&
      other.reportId == reportId &&
      other.showComments == showComments;

  @override
  int get hashCode => Object.hash(reportId, showComments);
}

/// Switch to the Messages tab (the inbox, not a specific conversation).
class MessagesTarget extends NotificationTarget {
  const MessagesTarget();

  @override
  bool operator ==(Object other) => other is MessagesTarget;

  @override
  int get hashCode => (MessagesTarget).hashCode;
}

/// The target for [item], or null when tapping only marks it read (nearby
/// alerts, unknown types, or a report notification without a report id).
NotificationTarget? notificationTargetFor(NotificationItem item) {
  switch (item.type) {
    case NotificationType.reportStatus:
    case NotificationType.reportLike:
    case NotificationType.comment:
      final reportId = item.reportId;
      if (reportId == null) return null;
      return ReportTarget(
        reportId,
        showComments: item.type == NotificationType.comment,
      );
    case NotificationType.chat:
      return const MessagesTarget();
    case NotificationType.sighting:
    case NotificationType.alert:
    case NotificationType.community:
    case NotificationType.system:
      return null;
  }
}

/// Short relative age for a notification: `Just now`, `5m ago`, `3h ago`,
/// `Yesterday`, `3d ago`, then a date (`Nov 3`, or `Nov 3, 2025` in an earlier
/// year). Days are calendar days in the local time zone. [now] is passed in so
/// tests can fix the clock.
String formatNotificationAge(DateTime createdAt, DateTime now) {
  final age = now.difference(createdAt);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';

  final created = createdAt.toLocal();
  final today = now.toLocal();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(created.year, created.month, created.day)).inDays;
  if (days <= 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${months[created.month - 1]} ${created.day}';
  return created.year == today.year ? date : '$date, ${created.year}';
}

/// State representation for the Notifications feature.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.activeFilter = NotificationsFilter.all,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.unreadTotal,
    this.error,
  });

  final List<NotificationItem> items;
  final NotificationsFilter activeFilter;
  final bool isLoading;
  final bool isLoadingMore;

  /// Whether older notifications can still be loaded.
  final bool hasMore;

  /// Unread notifications in total, which can exceed the loaded page. Null
  /// until known, in which case the loaded items are counted.
  final int? unreadTotal;
  final String? error;

  List<NotificationItem> get filteredItems {
    if (activeFilter == NotificationsFilter.unread) {
      return items.where((item) => item.isUnread).toList();
    }
    return items;
  }

  int get unreadCount =>
      unreadTotal ?? items.where((item) => item.isUnread).length;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    NotificationsFilter? activeFilter,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? unreadTotal,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      unreadTotal: unreadTotal ?? this.unreadTotal,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationsState &&
        other.activeFilter == activeFilter &&
        other.isLoading == isLoading &&
        other.isLoadingMore == isLoadingMore &&
        other.hasMore == hasMore &&
        other.unreadTotal == unreadTotal &&
        other.error == error &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    activeFilter,
    isLoading,
    isLoadingMore,
    hasMore,
    unreadTotal,
    error,
  );

  static bool _listEquals(List<NotificationItem> a, List<NotificationItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
