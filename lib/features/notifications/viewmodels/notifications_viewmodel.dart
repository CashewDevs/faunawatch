import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';

/// Presentation state manager for notifications.
class NotificationsViewModel extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    _loadNotifications();
    return const NotificationsState(isLoading: true);
  }

  NotificationsService get _service => ref.read(notificationsServiceProvider);

  Future<void> _loadNotifications() async {
    final items = await _service.getNotifications();
    state = state.copyWith(items: items, isLoading: false);
  }

  void setFilter(NotificationsFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
    final updated = [
      for (final item in state.items)
        if (item.id == id) item.copyWith(isUnread: false) else item,
    ];
    state = state.copyWith(items: updated);
  }

  Future<void> markAsUnread(String id) async {
    await _service.markAsUnread(id);
    final updated = [
      for (final item in state.items)
        if (item.id == id) item.copyWith(isUnread: true) else item,
    ];
    state = state.copyWith(items: updated);
  }

  Future<void> toggleReadStatus(String id) async {
    final target = state.items.firstWhere(
      (item) => item.id == id,
      orElse: () =>
          const NotificationItem(id: '', title: '', message: '', timestamp: ''),
    );
    if (target.id.isEmpty) return;

    if (target.isUnread) {
      await markAsRead(id);
    } else {
      await markAsUnread(id);
    }
  }

  Future<void> deleteNotification(String id) async {
    await _service.deleteNotification(id);
    final updated = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
    final updated = [
      for (final item in state.items) item.copyWith(isUnread: false),
    ];
    state = state.copyWith(items: updated);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadNotifications();
  }
}

/// Provider managing the notifications presentation state.
final notificationsViewModelProvider =
    NotifierProvider<NotificationsViewModel, NotificationsState>(
      NotificationsViewModel.new,
    );

/// Reactive provider indicating whether there are any unread notifications.
/// Used by ShellNavBar to show or hide the red circle notification badge.
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final state = ref.watch(notificationsViewModelProvider);
  return state.hasUnread;
});
