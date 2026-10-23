/// Categories for notifications in FaunaWatch.
enum NotificationType { sighting, alert, community, system }

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
  });

  final String id;
  final String title;
  final String message;
  final String timestamp;
  final bool isUnread;
  final NotificationType type;
  final String? avatarAsset;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? timestamp,
    bool? isUnread,
    NotificationType? type,
    String? avatarAsset,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isUnread: isUnread ?? this.isUnread,
      type: type ?? this.type,
      avatarAsset: avatarAsset ?? this.avatarAsset,
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
        other.avatarAsset == avatarAsset;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, message, timestamp, isUnread, type, avatarAsset);
}

/// State representation for the Notifications feature.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.activeFilter = NotificationsFilter.all,
    this.isLoading = false,
  });

  final List<NotificationItem> items;
  final NotificationsFilter activeFilter;
  final bool isLoading;

  List<NotificationItem> get filteredItems {
    if (activeFilter == NotificationsFilter.unread) {
      return items.where((item) => item.isUnread).toList();
    }
    return items;
  }

  int get unreadCount => items.where((item) => item.isUnread).length;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    NotificationsFilter? activeFilter,
    bool? isLoading,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationsState &&
        other.activeFilter == activeFilter &&
        other.isLoading == isLoading &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(items, activeFilter, isLoading);

  static bool _listEquals(List<NotificationItem> a, List<NotificationItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
