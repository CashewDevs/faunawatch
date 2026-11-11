import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';
import 'package:faunawatch/features/notifications/services/notifications_service.dart';

/// The current time, injectable so tests can fix relative labels like `5m ago`.
final notificationsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Presentation state manager for notifications.
///
/// Rebuilds, and so drops the previous user's notifications and live
/// subscription, when the service changes (sign-in, sign-out, account switch).
class NotificationsViewModel extends Notifier<NotificationsState> {
  late NotificationsService _service;
  int _generation = 0;
  int _request = 0;

  @override
  NotificationsState build() {
    _service = ref.watch(notificationsServiceProvider);
    final generation = ++_generation;
    StreamSubscription<void>? subscription;
    ref.onDispose(() {
      _generation++;
      subscription?.cancel();
    });
    Future.microtask(() {
      if (generation != _generation) return;
      try {
        subscription = _service.watchNotifications().listen(
          (_) => refresh(),
          onError: (_) {
            if (generation == _generation) {
              state = state.copyWith(
                error: 'Live updates disconnected. Pull down to refresh.',
              );
            }
          },
        );
      } catch (_) {
        /* Loading below reports authentication failures. */
      }
      refresh();
    });
    return const NotificationsState(isLoading: true);
  }

  List<NotificationItem> _labelled(List<NotificationItem> items) {
    final now = ref.read(notificationsClockProvider)();
    return [
      for (final item in items)
        item.createdAt == null
            ? item
            : item.copyWith(
                timestamp: formatNotificationAge(item.createdAt!, now),
              ),
    ];
  }

  static bool _isOlder(NotificationItem a, NotificationItem b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null || bTime == null) return false;
    final byTime = aTime.compareTo(bTime);
    return byTime < 0 || (byTime == 0 && a.id.compareTo(b.id) < 0);
  }

  /// Loads the newest page and the unread total. Older pages that were already
  /// loaded stay in the list, so a live update does not collapse it.
  Future<void> refresh() async {
    final generation = _generation;
    final request = ++_request;
    try {
      final results = await Future.wait<Object>([
        _service.getNotifications(),
        _service.countUnread(),
      ]);
      if (generation != _generation || request != _request) return;
      final fresh = results[0] as List<NotificationItem>;
      final unread = results[1] as int;
      final old = state.items;
      final pageIsFull = fresh.length >= NotificationsService.pageSize;
      final tail = pageIsFull
          ? old.where((item) => _isOlder(item, fresh.last)).toList()
          : <NotificationItem>[];
      state = state.copyWith(
        items: _labelled([...fresh, ...tail]),
        hasMore: tail.isNotEmpty ? state.hasMore : pageIsFull,
        unreadTotal: unread,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      if (generation == _generation && request == _request) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Could not load notifications. Check your connection and try again.',
        );
      }
    }
  }

  /// Retries after a failed load, showing the loading indicator.
  Future<void> retry() {
    state = state.copyWith(isLoading: true, clearError: true);
    return refresh();
  }

  /// Appends the next page of older notifications.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.items.isEmpty) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _service.getNotifications(before: state.items.last);
      if (generation != _generation) return;
      final known = {for (final item in state.items) item.id};
      state = state.copyWith(
        items: [
          ...state.items,
          ..._labelled(page.where((item) => !known.contains(item.id)).toList()),
        ],
        hasMore: page.length >= NotificationsService.pageSize,
        isLoadingMore: false,
      );
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isLoadingMore: false,
          error: 'Could not load older notifications. Please try again.',
        );
      }
    }
  }

  void setFilter(NotificationsFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  /// Runs [action], then applies its result locally. On failure the list is
  /// left as it was and an error is shown.
  Future<void> _change(
    Future<void> Function() action,
    NotificationsState Function(NotificationsState) apply,
  ) async {
    final generation = _generation;
    try {
      await action();
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          error: 'Could not update this notification. Please try again.',
        );
      }
      return;
    }
    if (generation != _generation) return;
    // A refresh that started before this change would show the old state.
    ++_request;
    state = apply(state).copyWith(clearError: true);
  }

  NotificationsState _setUnread(NotificationsState s, String id, bool unread) {
    final item = s.items.where((i) => i.id == id).firstOrNull;
    if (item == null || item.isUnread == unread) return s;
    final total = s.unreadTotal;
    return s.copyWith(
      items: [
        for (final i in s.items)
          if (i.id == id) i.copyWith(isUnread: unread) else i,
      ],
      unreadTotal: total == null ? null : max(0, total + (unread ? 1 : -1)),
    );
  }

  Future<void> markAsRead(String id) =>
      _change(() => _service.markAsRead(id), (s) => _setUnread(s, id, false));

  Future<void> markAsUnread(String id) =>
      _change(() => _service.markAsUnread(id), (s) => _setUnread(s, id, true));

  Future<void> toggleReadStatus(String id) async {
    final target = state.items.where((item) => item.id == id).firstOrNull;
    if (target == null) return;
    if (target.isUnread) {
      await markAsRead(id);
    } else {
      await markAsUnread(id);
    }
  }

  Future<void> deleteNotification(String id) =>
      _change(() => _service.deleteNotification(id), (s) {
        final item = s.items.where((i) => i.id == id).firstOrNull;
        final total = s.unreadTotal;
        return s.copyWith(
          items: s.items.where((i) => i.id != id).toList(),
          unreadTotal: total == null || item == null || !item.isUnread
              ? null
              : max(0, total - 1),
        );
      });

  Future<void> markAllAsRead() => _change(
    _service.markAllAsRead,
    (s) => s.copyWith(
      items: [for (final item in s.items) item.copyWith(isUnread: false)],
      unreadTotal: 0,
    ),
  );
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
