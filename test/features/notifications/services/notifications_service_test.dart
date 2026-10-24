import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';

void main() {
  group('FaunaNotificationsService', () {
    late FaunaNotificationsService service;

    setUp(() {
      service = FaunaNotificationsService(
        initialItems: [
          const NotificationItem(
            id: 'n1',
            title: 'Notif 1',
            message: 'Message 1',
            timestamp: '5m',
            isUnread: true,
          ),
          const NotificationItem(
            id: 'n2',
            title: 'Notif 2',
            message: 'Message 2',
            timestamp: '1h',
            isUnread: false,
          ),
        ],
      );
    });

    test('getNotifications returns initial notifications', () async {
      final items = await service.getNotifications();
      expect(items.length, 2);
      expect(items.first.id, 'n1');
    });

    test('markAsRead changes isUnread to false', () async {
      await service.markAsRead('n1');
      final items = await service.getNotifications();
      expect(items.firstWhere((i) => i.id == 'n1').isUnread, isFalse);
    });

    test('markAsUnread changes isUnread to true', () async {
      await service.markAsUnread('n2');
      final items = await service.getNotifications();
      expect(items.firstWhere((i) => i.id == 'n2').isUnread, isTrue);
    });

    test('deleteNotification removes item from service', () async {
      await service.deleteNotification('n1');
      final items = await service.getNotifications();
      expect(items.length, 1);
      expect(items.any((i) => i.id == 'n1'), isFalse);
    });

    test('markAllAsRead marks all notifications as read', () async {
      await service.markAllAsRead();
      final items = await service.getNotifications();
      expect(items.every((i) => !i.isUnread), isTrue);
    });
  });
}
