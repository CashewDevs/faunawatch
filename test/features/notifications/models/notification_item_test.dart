import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

void main() {
  group('NotificationItem', () {
    test('instantiates with expected default values', () {
      const item = NotificationItem(
        id: '1',
        title: 'Title',
        message: 'Message',
        timestamp: '1h ago',
      );

      expect(item.id, '1');
      expect(item.title, 'Title');
      expect(item.message, 'Message');
      expect(item.timestamp, '1h ago');
      expect(item.isUnread, isFalse);
      expect(item.type, NotificationType.system);
      expect(item.avatarAsset, isNull);
    });

    test('copyWith updates properties correctly', () {
      const item = NotificationItem(
        id: '1',
        title: 'Title',
        message: 'Message',
        timestamp: '1h ago',
        isUnread: true,
      );

      final updated = item.copyWith(isUnread: false, title: 'New Title');

      expect(updated.id, '1');
      expect(updated.title, 'New Title');
      expect(updated.isUnread, isFalse);
      expect(updated.message, 'Message');
    });

    test('supports value equality', () {
      const item1 = NotificationItem(
        id: '1',
        title: 'Title',
        message: 'Message',
        timestamp: '1h ago',
      );
      const item2 = NotificationItem(
        id: '1',
        title: 'Title',
        message: 'Message',
        timestamp: '1h ago',
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('NotificationsState', () {
    test(
      'filteredItems returns unread items only when unread filter is active',
      () {
        const item1 = NotificationItem(
          id: '1',
          title: 'Unread Item',
          message: 'M',
          timestamp: 'T',
          isUnread: true,
        );
        const item2 = NotificationItem(
          id: '2',
          title: 'Read Item',
          message: 'M',
          timestamp: 'T',
          isUnread: false,
        );

        final state = const NotificationsState(
          items: [item1, item2],
          activeFilter: NotificationsFilter.unread,
        );

        expect(state.filteredItems, [item1]);
        expect(state.unreadCount, 1);
        expect(state.hasUnread, isTrue);
      },
    );

    test('filteredItems returns all items when all filter is active', () {
      const item1 = NotificationItem(
        id: '1',
        title: 'Unread Item',
        message: 'M',
        timestamp: 'T',
        isUnread: true,
      );
      const item2 = NotificationItem(
        id: '2',
        title: 'Read Item',
        message: 'M',
        timestamp: 'T',
        isUnread: false,
      );

      final state = const NotificationsState(
        items: [item1, item2],
        activeFilter: NotificationsFilter.all,
      );

      expect(state.filteredItems.length, 2);
    });

    test('hasUnread is false when no items are unread', () {
      const item = NotificationItem(
        id: '1',
        title: 'Read',
        message: 'M',
        timestamp: 'T',
        isUnread: false,
      );

      const state = NotificationsState(items: [item]);

      expect(state.unreadCount, 0);
      expect(state.hasUnread, isFalse);
    });
  });
}
