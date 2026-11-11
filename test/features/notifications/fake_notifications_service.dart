import 'dart:async';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';

/// In-memory [NotificationsService] for tests: no network, and [emitLive]
/// stands in for a Realtime event.
class FakeNotificationsService implements NotificationsService {
  FakeNotificationsService({List<NotificationItem>? items})
    : items = List<NotificationItem>.from(items ?? const []);

  /// Newest first, like the real service returns them.
  final List<NotificationItem> items;
  final StreamController<void> _live = StreamController<void>.broadcast();

  bool failLoading = false;
  bool failChanges = false;
  int listeners = 0;
  int loads = 0;
  final List<NotificationItem?> cursors = [];

  void emitLive() => _live.add(null);
  void emitLiveError() => _live.addError(StateError('disconnected'));

  @override
  Future<List<NotificationItem>> getNotifications({
    NotificationItem? before,
  }) async {
    loads++;
    cursors.add(before);
    if (failLoading) throw StateError('load failed');
    var start = 0;
    if (before != null) {
      start = items.indexWhere((item) => item.id == before.id) + 1;
    }
    return items.skip(start).take(NotificationsService.pageSize).toList();
  }

  @override
  Future<int> countUnread() async {
    if (failLoading) throw StateError('load failed');
    return items.where((item) => item.isUnread).length;
  }

  void _replace(String id, bool unread) {
    if (failChanges) throw StateError('update failed');
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) items[index] = items[index].copyWith(isUnread: unread);
  }

  @override
  Future<void> markAsRead(String id) async => _replace(id, false);

  @override
  Future<void> markAsUnread(String id) async => _replace(id, true);

  @override
  Future<void> deleteNotification(String id) async {
    if (failChanges) throw StateError('delete failed');
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> markAllAsRead() async {
    if (failChanges) throw StateError('update failed');
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(isUnread: false);
    }
  }

  @override
  Stream<void> watchNotifications() {
    listeners++;
    return _live.stream;
  }
}
