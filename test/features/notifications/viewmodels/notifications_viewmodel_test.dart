import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';
import '../fake_notifications_service.dart';

NotificationItem item(
  String id, {
  bool unread = false,
  DateTime? createdAt,
  String title = 'Title',
}) => NotificationItem(
  id: id,
  title: title,
  message: 'Body $id',
  timestamp: '',
  isUnread: unread,
  type: NotificationType.reportStatus,
  createdAt: createdAt,
);

void main() {
  final now = DateTime.utc(2026, 11, 12, 12, 0);

  group('NotificationsViewModel', () {
    late ProviderContainer container;
    late FakeNotificationsService service;

    ProviderContainer build(FakeNotificationsService fake) {
      final created = ProviderContainer(
        overrides: [
          notificationsServiceProvider.overrideWithValue(fake),
          notificationsClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(created.dispose);
      return created;
    }

    NotificationsState read() => container.read(notificationsViewModelProvider);
    NotificationsViewModel vm() =>
        container.read(notificationsViewModelProvider.notifier);

    Future<void> load() async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();
    }

    setUp(() {
      service = FakeNotificationsService(
        items: [
          item(
            'n1',
            unread: true,
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
          item('n2', createdAt: now.subtract(const Duration(days: 1))),
        ],
      );
      container = build(service);
    });

    test('starts loading, then shows notifications with age labels', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      expect(read().isLoading, isTrue);

      await pumpEventQueue();

      expect(read().isLoading, isFalse);
      expect(read().items.map((i) => i.id), ['n1', 'n2']);
      expect(read().items.map((i) => i.timestamp), ['5m ago', 'Yesterday']);
      expect(read().hasUnread, isTrue);
      expect(read().unreadCount, 1);
      expect(read().error, isNull);
      expect(service.listeners, 1);
    });

    test('keeps the given label when an item has no createdAt', () async {
      service = FakeNotificationsService(
        items: [
          const NotificationItem(
            id: 'x',
            title: 'T',
            message: 'M',
            timestamp: 'Earlier',
          ),
        ],
      );
      container = build(service);
      await load();

      expect(read().items.single.timestamp, 'Earlier');
    });

    test('a failed load shows an error, and retry recovers', () async {
      service.failLoading = true;
      await load();

      expect(read().isLoading, isFalse);
      expect(read().items, isEmpty);
      expect(read().error, contains('Could not load notifications'));

      service.failLoading = false;
      await vm().retry();

      expect(read().error, isNull);
      expect(read().items, hasLength(2));
    });

    test(
      'a live event adds a new notification and updates the badge',
      () async {
        service = FakeNotificationsService(items: [item('n2')]);
        container = build(service);
        await load();
        expect(read().hasUnread, isFalse);

        service.items.insert(
          0,
          item(
            'n3',
            unread: true,
            createdAt: now.subtract(const Duration(seconds: 10)),
          ),
        );
        service.emitLive();
        await pumpEventQueue();

        expect(read().items.map((i) => i.id), ['n3', 'n2']);
        expect(read().items.first.timestamp, 'Just now');
        expect(read().unreadCount, 1);
        expect(container.read(hasUnreadNotificationsProvider), isTrue);
      },
    );

    test('a live event reflects a notification changed elsewhere', () async {
      await load();

      service.items[1] = service.items[1].copyWith(isUnread: true);
      service.emitLive();
      await pumpEventQueue();

      expect(read().unreadCount, 2);
    });

    test(
      'a live connection error shows a message and keeps the list',
      () async {
        await load();

        service.emitLiveError();
        await pumpEventQueue();

        expect(read().error, contains('Live updates disconnected'));
        expect(read().items, hasLength(2));
      },
    );

    test('setFilter updates active filter', () async {
      await load();

      vm().setFilter(NotificationsFilter.unread);

      expect(read().activeFilter, NotificationsFilter.unread);
      expect(read().filteredItems.map((i) => i.id), ['n1']);
    });

    test('markAsRead marks an unread item read and clears the badge', () async {
      await load();

      await vm().markAsRead('n1');

      expect(read().hasUnread, isFalse);
      expect(read().unreadCount, 0);
      expect(read().items.firstWhere((i) => i.id == 'n1').isUnread, isFalse);
      expect(service.items.first.isUnread, isFalse);
      expect(container.read(hasUnreadNotificationsProvider), isFalse);
    });

    test('markAsUnread marks a read item unread', () async {
      await load();

      await vm().markAsUnread('n2');

      expect(read().unreadCount, 2);
      expect(read().items.firstWhere((i) => i.id == 'n2').isUnread, isTrue);
      expect(service.items.last.isUnread, isTrue);
    });

    test('toggleReadStatus inverts unread status', () async {
      await load();

      await vm().toggleReadStatus('n1');
      expect(read().items.first.isUnread, isFalse);

      await vm().toggleReadStatus('n1');
      expect(read().items.first.isUnread, isTrue);
    });

    test('toggleReadStatus ignores an unknown id', () async {
      await load();

      await vm().toggleReadStatus('missing');

      expect(read().items, hasLength(2));
      expect(read().error, isNull);
    });

    test('deleteNotification removes the item and lowers the count', () async {
      await load();

      await vm().deleteNotification('n1');

      expect(read().items.map((i) => i.id), ['n2']);
      expect(read().hasUnread, isFalse);
      expect(service.items.map((i) => i.id), ['n2']);
    });

    test('deleting a read item keeps the unread count', () async {
      await load();

      await vm().deleteNotification('n2');

      expect(read().unreadCount, 1);
    });

    test('markAllAsRead reads everything', () async {
      service.items.add(item('n3', unread: true));
      await load();
      expect(read().unreadCount, 2);

      await vm().markAllAsRead();

      expect(read().unreadCount, 0);
      expect(read().items.every((i) => !i.isUnread), isTrue);
      expect(service.items.every((i) => !i.isUnread), isTrue);
    });

    test(
      'a failed change leaves the list as it was and shows an error',
      () async {
        await load();
        service.failChanges = true;

        await vm().markAsRead('n1');
        expect(read().items.first.isUnread, isTrue);
        expect(read().unreadCount, 1);
        expect(read().error, contains('Could not update'));

        await vm().deleteNotification('n1');
        expect(read().items, hasLength(2));

        await vm().markAllAsRead();
        expect(read().unreadCount, 1);
      },
    );

    test('the badge counts unread notifications that are not loaded', () async {
      service = FakeNotificationsService(
        items: [
          for (var i = 0; i < 60; i++)
            item(
              'n${i.toString().padLeft(2, '0')}',
              unread: i >= 55,
              createdAt: now.subtract(Duration(minutes: i)),
            ),
        ],
      );
      container = build(service);
      await load();

      expect(read().items, hasLength(50));
      expect(read().items.any((i) => i.isUnread), isFalse);
      expect(read().unreadCount, 5);
      expect(read().hasUnread, isTrue);
    });

    test('loadMore appends the next page after the last item', () async {
      service = FakeNotificationsService(
        items: [
          for (var i = 0; i < 60; i++)
            item(
              'n${i.toString().padLeft(2, '0')}',
              createdAt: now.subtract(Duration(minutes: i)),
            ),
        ],
      );
      container = build(service);
      await load();
      expect(read().hasMore, isTrue);

      await vm().loadMore();

      expect(read().items, hasLength(60));
      expect(read().hasMore, isFalse);
      expect(service.cursors.last?.id, 'n49');
      expect(read().isLoadingMore, isFalse);
    });

    test(
      'loadMore does nothing when there are no older notifications',
      () async {
        await load();
        final loads = service.loads;

        await vm().loadMore();

        expect(read().hasMore, isFalse);
        expect(service.loads, loads);
      },
    );

    test('a live refresh keeps older pages that were already loaded', () async {
      service = FakeNotificationsService(
        items: [
          for (var i = 0; i < 60; i++)
            item(
              'n${i.toString().padLeft(2, '0')}',
              createdAt: now.subtract(Duration(minutes: i)),
            ),
        ],
      );
      container = build(service);
      await load();
      await vm().loadMore();
      expect(read().items, hasLength(60));

      service.emitLive();
      await pumpEventQueue();

      expect(read().items, hasLength(60));
      expect(read().hasMore, isFalse);
    });

    test('signing out clears notifications and stops listening', () async {
      final signedIn = FakeNotificationsService(
        items: [item('n1', unread: true)],
      );
      var current = signedIn as NotificationsService;
      final account = ProviderContainer(
        overrides: [
          notificationsServiceProvider.overrideWith((ref) => current),
          notificationsClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(account.dispose);
      account.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();
      expect(account.read(notificationsViewModelProvider).items, hasLength(1));

      current = const SignedOutNotificationsService();
      account.invalidate(notificationsServiceProvider);
      await pumpEventQueue();

      final state = account.read(notificationsViewModelProvider);
      expect(state.items, isEmpty);
      expect(state.hasUnread, isFalse);
      expect(state.isLoading, isFalse);
      // The previous account's late events no longer change anything.
      signedIn.items.add(item('late', unread: true));
      signedIn.emitLive();
      await pumpEventQueue();
      expect(account.read(notificationsViewModelProvider).items, isEmpty);
    });
  });
}
