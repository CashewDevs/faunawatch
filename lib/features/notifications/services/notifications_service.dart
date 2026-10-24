import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// Contract for notifications operations.
abstract class NotificationsService {
  Future<List<NotificationItem>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAsUnread(String id);
  Future<void> deleteNotification(String id);
  Future<void> markAllAsRead();
}

/// In-memory implementation providing initial wildlife alerts and report notifications.
class FaunaNotificationsService implements NotificationsService {
  FaunaNotificationsService({List<NotificationItem>? initialItems})
    : _items = initialItems != null
          ? List<NotificationItem>.from(initialItems)
          : _defaultNotifications();

  final List<NotificationItem> _items;

  static List<NotificationItem> _defaultNotifications() {
    return [
      const NotificationItem(
        id: 'notif-1',
        title: 'New Sighting Nearby',
        message:
            'A Philippine Eagle was recently spotted 2.4 km from your current area.',
        timestamp: '5m ago',
        isUnread: true,
        type: NotificationType.sighting,
      ),
      const NotificationItem(
        id: 'notif-2',
        title: 'Report Verified',
        message:
            'Your reported sighting of Palawan Hornbill has been verified by community experts.',
        timestamp: '1h ago',
        isUnread: false,
        type: NotificationType.community,
      ),
      const NotificationItem(
        id: 'notif-3',
        title: 'Conservation Alert',
        message:
            'Invasive species notice issued for Protected Zone Alpha. Please report any Cane Toad sightings.',
        timestamp: '3h ago',
        isUnread: false,
        type: NotificationType.alert,
      ),
      const NotificationItem(
        id: 'notif-4',
        title: 'Welcome to FaunaWatch',
        message:
            'Thank you for joining our community of wildlife observers and conservationists.',
        timestamp: 'Yesterday',
        isUnread: false,
        type: NotificationType.system,
      ),
    ];
  }

  @override
  Future<List<NotificationItem>> getNotifications() async {
    return List<NotificationItem>.from(_items);
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isUnread: false);
    }
  }

  @override
  Future<void> markAsUnread(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isUnread: true);
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].isUnread) {
        _items[i] = _items[i].copyWith(isUnread: false);
      }
    }
  }
}

/// Global provider for the notifications service.
final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return FaunaNotificationsService();
});
