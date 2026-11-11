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

    test('unreadTotal covers notifications that are not loaded', () {
      const read = NotificationItem(
        id: '1',
        title: 'Read',
        message: 'M',
        timestamp: 'T',
      );

      const state = NotificationsState(items: [read], unreadTotal: 3);

      expect(state.unreadCount, 3);
      expect(state.hasUnread, isTrue);
    });
  });

  group('NotificationItem.fromJson', () {
    Map<String, dynamic> row({String type = 'report_status', String? readAt}) =>
        {
          'id': 'n-1',
          'user_id': 'user-a',
          'type': type,
          'title': 'Your report was approved',
          'body': 'It is now visible to the community.',
          'report_id': 'report-1',
          'thread_id': null,
          'actor_id': null,
          'read_at': readAt,
          'created_at': '2026-11-12T08:30:00+00:00',
        };

    test('maps a database row', () {
      final item = NotificationItem.fromJson(row());

      expect(item.id, 'n-1');
      expect(item.title, 'Your report was approved');
      expect(item.message, 'It is now visible to the community.');
      expect(item.isUnread, isTrue);
      expect(item.type, NotificationType.reportStatus);
      expect(item.reportId, 'report-1');
      expect(item.threadId, isNull);
      expect(item.createdAt, DateTime.utc(2026, 11, 12, 8, 30));
      expect(item.timestamp, isEmpty);
    });

    test('a row with read_at is read', () {
      final item = NotificationItem.fromJson(
        row(readAt: '2026-11-12T09:00:00+00:00'),
      );

      expect(item.isUnread, isFalse);
    });

    test('maps every database type to a UI type', () {
      expect(
        notificationTypeFromDb('report_status'),
        NotificationType.reportStatus,
      );
      expect(
        notificationTypeFromDb('report_comment'),
        NotificationType.comment,
      );
      expect(notificationTypeFromDb('chat_message'), NotificationType.chat);
      expect(notificationTypeFromDb('nearby_alert'), NotificationType.alert);
    });

    test('an unknown type falls back to system', () {
      expect(notificationTypeFromDb('something_new'), NotificationType.system);
      expect(notificationTypeFromDb(null), NotificationType.system);
    });

    test('keeps the chat conversation reference', () {
      final item = NotificationItem.fromJson({
        ...row(type: 'chat_message'),
        'report_id': null,
        'thread_id': 'thread-1',
      });

      expect(item.type, NotificationType.chat);
      expect(item.threadId, 'thread-1');
      expect(item.reportId, isNull);
    });
  });

  group('formatNotificationAge', () {
    final now = DateTime(2026, 11, 12, 15, 0);

    String age(Duration ago) => formatNotificationAge(now.subtract(ago), now);

    test('under a minute is Just now, including a clock ahead of ours', () {
      expect(age(const Duration(seconds: 20)), 'Just now');
      expect(age(const Duration(seconds: -30)), 'Just now');
    });

    test('minutes and hours', () {
      expect(age(const Duration(minutes: 5)), '5m ago');
      expect(age(const Duration(minutes: 59)), '59m ago');
      expect(age(const Duration(hours: 1)), '1h ago');
      expect(age(const Duration(hours: 23, minutes: 59)), '23h ago');
    });

    test('the previous calendar day is Yesterday', () {
      expect(
        formatNotificationAge(DateTime(2026, 11, 11, 9), now),
        'Yesterday',
      );
      expect(age(const Duration(hours: 24)), 'Yesterday');
    });

    test('two to six days ago', () {
      expect(formatNotificationAge(DateTime(2026, 11, 10, 9), now), '2d ago');
      expect(formatNotificationAge(DateTime(2026, 11, 6, 9), now), '6d ago');
    });

    test('a week or more ago is a date, with the year when it differs', () {
      expect(formatNotificationAge(DateTime(2026, 11, 5, 9), now), 'Nov 5');
      expect(formatNotificationAge(DateTime(2026, 1, 3, 9), now), 'Jan 3');
      expect(
        formatNotificationAge(DateTime(2025, 12, 31, 9), now),
        'Dec 31, 2025',
      );
    });
  });
}
