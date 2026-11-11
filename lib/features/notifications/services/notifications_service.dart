import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/auth/services/auth_service.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// Contract for notifications operations.
abstract interface class NotificationsService {
  static const pageSize = 50;

  /// Newest first. Pass the last item of the previous page as [before] to load
  /// the next, older [pageSize] notifications.
  Future<List<NotificationItem>> getNotifications({NotificationItem? before});

  /// How many notifications are unread, including ones not loaded yet.
  Future<int> countUnread();
  Future<void> markAsRead(String id);
  Future<void> markAsUnread(String id);
  Future<void> deleteNotification(String id);
  Future<void> markAllAsRead();

  /// Emits whenever the signed-in user's notifications may have changed, and
  /// once the live connection is up. Errors mean the connection dropped.
  Stream<void> watchNotifications();
}

/// Reads and updates the signed-in user's rows in `notifications`.
///
/// Rows are created only by database triggers; RLS and a column grant let the
/// client read, delete and change `read_at` on its own rows.
class SupabaseNotificationsService implements NotificationsService {
  SupabaseNotificationsService(this._client);
  final SupabaseClient _client;
  static int _channelSequence = 0;

  String get _userId =>
      _client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to see notifications.'));

  @override
  Future<List<NotificationItem>> getNotifications({
    NotificationItem? before,
  }) async {
    final userId = _userId;
    var query = _client.from('notifications').select().eq('user_id', userId);
    final cursor = before?.createdAt;
    if (before != null && cursor != null) {
      final date = cursor.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(NotificationsService.pageSize);
    return rows.map(NotificationItem.fromJson).toList();
  }

  @override
  Future<int> countUnread() async {
    final userId = _userId;
    return await _client
        .from('notifications')
        .count()
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  Future<void> _setReadAt(String id, DateTime? readAt) async {
    final userId = _userId;
    await _client
        .from('notifications')
        .update({'read_at': readAt?.toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<void> markAsRead(String id) => _setReadAt(id, DateTime.now());

  @override
  Future<void> markAsUnread(String id) => _setReadAt(id, null);

  @override
  Future<void> deleteNotification(String id) async {
    final userId = _userId;
    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _userId;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  @override
  Stream<void> watchNotifications() {
    final userId = _userId;
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        // Deletes are not filtered by column in Realtime, so they may not
        // arrive; the ViewModel removes deleted rows itself.
        channel = _client
            .channel('notifications:$userId:${_channelSequence++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe((status, error) {
              if (controller.isClosed) return;
              // Also emitted when (re)connected, which fetches missed rows.
              if (status == RealtimeSubscribeStatus.subscribed) {
                controller.add(null);
              }
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                controller.addError(
                  StateError(
                    'Live updates disconnected. Refresh to try again.',
                  ),
                );
              }
            });
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}

/// Used while signed out or restoring the session: no client or subscription
/// is kept, and the list is empty.
class SignedOutNotificationsService implements NotificationsService {
  const SignedOutNotificationsService();
  Never _signIn() => throw const AuthException('Sign in to see notifications.');

  @override
  Future<List<NotificationItem>> getNotifications({
    NotificationItem? before,
  }) async => const [];
  @override
  Future<int> countUnread() async => 0;
  @override
  Future<void> markAsRead(String id) async => _signIn();
  @override
  Future<void> markAsUnread(String id) async => _signIn();
  @override
  Future<void> deleteNotification(String id) async => _signIn();
  @override
  Future<void> markAllAsRead() async => _signIn();
  @override
  Stream<void> watchNotifications() => const Stream.empty();
}

/// Global provider for the notifications service. Changes with the signed-in
/// user, which rebuilds the ViewModel and drops the previous user's state and
/// subscription.
final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  if (ref.watch(currentUserIdProvider).valueOrNull == null) {
    return const SignedOutNotificationsService();
  }
  return SupabaseNotificationsService(ref.watch(supabaseClientProvider));
});
