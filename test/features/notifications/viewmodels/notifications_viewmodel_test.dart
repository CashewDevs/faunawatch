import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';
import 'package:faunawatch/features/notifications/viewmodels/notifications_viewmodel.dart';

void main() {
  group('NotificationsViewModel', () {
    late ProviderContainer container;
    late FaunaNotificationsService mockService;

    setUp(() {
      mockService = FaunaNotificationsService(
        initialItems: [
          const NotificationItem(
            id: 'n1',
            title: 'Unread Notif',
            message: 'Body 1',
            timestamp: 'Now',
            isUnread: true,
          ),
          const NotificationItem(
            id: 'n2',
            title: 'Read Notif',
            message: 'Body 2',
            timestamp: 'Yesterday',
            isUnread: false,
          ),
        ],
      );

      container = ProviderContainer(
        overrides: [
          notificationsServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes and loads notifications', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final state = container.read(notificationsViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.items.length, 2);
      expect(state.hasUnread, isTrue);
      expect(state.unreadCount, 1);
    });

    test('setFilter updates active filter', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewModel = container.read(notificationsViewModelProvider.notifier);
      viewModel.setFilter(NotificationsFilter.unread);

      final state = container.read(notificationsViewModelProvider);
      expect(state.activeFilter, NotificationsFilter.unread);
      expect(state.filteredItems.length, 1);
      expect(state.filteredItems.first.id, 'n1');
    });

    test('markAsRead marks unread item as read', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewModel = container.read(notificationsViewModelProvider.notifier);
      await viewModel.markAsRead('n1');

      final state = container.read(notificationsViewModelProvider);
      expect(state.hasUnread, isFalse);
      expect(state.unreadCount, 0);
      expect(state.items.firstWhere((i) => i.id == 'n1').isUnread, isFalse);
    });

    test('markAsUnread marks read item as unread', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewModel = container.read(notificationsViewModelProvider.notifier);
      await viewModel.markAsUnread('n2');

      final state = container.read(notificationsViewModelProvider);
      expect(state.unreadCount, 2);
      expect(state.items.firstWhere((i) => i.id == 'n2').isUnread, isTrue);
    });

    test('toggleReadStatus inverts unread status', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewModel = container.read(notificationsViewModelProvider.notifier);
      await viewModel.toggleReadStatus('n1'); // was unread, becomes read
      expect(
        container
            .read(notificationsViewModelProvider)
            .items
            .firstWhere((i) => i.id == 'n1')
            .isUnread,
        isFalse,
      );

      await viewModel.toggleReadStatus('n1'); // becomes unread again
      expect(
        container
            .read(notificationsViewModelProvider)
            .items
            .firstWhere((i) => i.id == 'n1')
            .isUnread,
        isTrue,
      );
    });

    test('deleteNotification removes notification item', () async {
      container.listen(notificationsViewModelProvider, (_, _) {});
      await pumpEventQueue();

      final viewModel = container.read(notificationsViewModelProvider.notifier);
      await viewModel.deleteNotification('n1');

      final state = container.read(notificationsViewModelProvider);
      expect(state.items.length, 1);
      expect(state.items.any((i) => i.id == 'n1'), isFalse);
      expect(state.hasUnread, isFalse);
    });

    test(
      'hasUnreadNotificationsProvider reactively reflects unread state',
      () async {
        container.listen(notificationsViewModelProvider, (_, _) {});
        await pumpEventQueue();

        expect(container.read(hasUnreadNotificationsProvider), isTrue);

        final viewModel = container.read(
          notificationsViewModelProvider.notifier,
        );
        await viewModel.markAsRead('n1');

        expect(container.read(hasUnreadNotificationsProvider), isFalse);
      },
    );
  });
}
