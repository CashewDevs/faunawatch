import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import '../fake_notifications_service.dart';

NotificationItem typed(
  String id,
  NotificationType type, {
  bool unread = true,
  String? reportId,
}) => NotificationItem(
  id: id,
  title: 'Title',
  message: 'Body',
  timestamp: '',
  isUnread: unread,
  type: type,
  reportId: reportId,
  createdAt: DateTime.utc(2026, 11, 12, 11),
);

void main() {
  late ProviderContainer container;
  late FakeNotificationsService service;

  Future<void> load(List<NotificationItem> items) async {
    service = FakeNotificationsService(items: items);
    container = ProviderContainer(
      overrides: [notificationsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(notificationsViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  NotificationsState read() => container.read(notificationsViewModelProvider);
  NotificationsViewModel vm() =>
      container.read(notificationsViewModelProvider.notifier);

  group('clear all', () {
    test('empties the list and the unread count', () async {
      await load([
        typed('a', NotificationType.reportLike, reportId: 'r1'),
        typed('b', NotificationType.chat, unread: false),
      ]);
      expect(read().unreadCount, 1);

      await vm().clearAll();

      expect(service.deleteAllCalls, 1);
      expect(service.items, isEmpty);
      expect(read().items, isEmpty);
      expect(read().unreadCount, 0);
      expect(read().hasMore, isFalse);
      expect(read().error, isNull);
    });

    test('failure keeps the list and shows an error', () async {
      await load([typed('a', NotificationType.reportLike, reportId: 'r1')]);
      service.failChanges = true;

      await vm().clearAll();

      expect(read().items, hasLength(1));
      expect(read().unreadCount, 1);
      expect(read().error, 'Could not clear notifications. Please try again.');
    });
  });

  group('tap', () {
    test('report types open that report; comments show the comments', () async {
      await load([
        typed('s', NotificationType.reportStatus, reportId: 'r1'),
        typed('l', NotificationType.reportLike, reportId: 'r2'),
        typed('c', NotificationType.comment, reportId: 'r3'),
      ]);

      expect(await vm().open(read().items[0]), const ReportTarget('r1'));
      expect(await vm().open(read().items[1]), const ReportTarget('r2'));
      expect(
        await vm().open(read().items[2]),
        const ReportTarget('r3', showComments: true),
      );
    });

    test('a chat notification targets the Messages tab', () async {
      await load([typed('m', NotificationType.chat)]);

      expect(await vm().open(read().items.single), const MessagesTarget());
    });

    test('alerts, unknown types and missing ids only mark read', () async {
      await load([
        typed('a', NotificationType.alert),
        typed('u', NotificationType.system),
        typed('x', NotificationType.reportStatus),
      ]);

      for (final item in List.of(read().items)) {
        expect(await vm().open(item), isNull);
      }
      expect(read().unreadCount, 0);
    });

    test('marks an unread notification read and keeps it', () async {
      await load([typed('l', NotificationType.reportLike, reportId: 'r2')]);

      await vm().open(read().items.single);

      expect(read().items.single.isUnread, isFalse);
      expect(read().unreadCount, 0);
    });

    test('a failed mark-read still returns the target', () async {
      await load([typed('l', NotificationType.reportLike, reportId: 'r2')]);
      service.failChanges = true;

      final target = await vm().open(read().items.single);

      expect(target, const ReportTarget('r2'));
      expect(read().error, isNotNull);
    });
  });
}
