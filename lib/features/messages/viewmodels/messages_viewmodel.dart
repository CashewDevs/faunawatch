import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_time.dart';
export 'package:faunawatch/features/messages/models/message_thread.dart';

class MessagesViewModel extends Notifier<MessagesState> {
  late MessagesService _service;
  int _generation = 0;
  int _request = 0;
  @override
  MessagesState build() {
    _service = ref.watch(messagesServiceProvider);
    final generation = ++_generation;
    StreamSubscription<void>? subscription;
    ref.onDispose(() {
      _generation++;
      subscription?.cancel();
    });
    Future.microtask(() {
      if (generation != _generation) return;
      try {
        subscription = _service.watchInbox().listen(
          (_) => refresh(),
          onError: (_) {
            if (generation == _generation) {
              state = state.copyWith(
                error: 'Live updates disconnected. Refresh to try again.',
              );
            }
          },
        );
      } catch (_) {
        /* Loading below reports authentication failures. */
      }
      refresh();
    });
    return const MessagesState(isLoading: true);
  }

  Future<void> refresh() async {
    final generation = _generation;
    final request = ++_request;
    try {
      final threads = await _service.fetchMessageThreads();
      if (generation != _generation || request != _request) return;
      state = state.copyWith(
        threads: threads
            .map(
              (t) => t.copyWith(
                timestamp: chatTime(t.lastMessageAt, fallback: t.timestamp),
              ),
            )
            .toList(),
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      if (generation == _generation && request == _request) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Could not load messages. Check your connection and try again.',
        );
      }
    }
  }

  void setFilter(MessagesFilter filter) =>
      state = state.copyWith(activeFilter: filter);
  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);
  Future<void> _change(
    String id,
    Future<bool> Function() action,
    MessageThread Function(MessageThread)? update,
  ) async {
    final generation = _generation;
    try {
      if (!await action()) throw StateError('Inbox update failed');
      if (generation != _generation) return;
      ++_request;
      state = state.copyWith(
        clearError: true,
        threads: update == null
            ? state.threads.where((t) => t.id != id).toList()
            : state.threads.map((t) => t.id == id ? update(t) : t).toList(),
      );
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          error: 'Could not update this conversation. Please try again.',
        );
      }
    }
  }

  Future<void> markThreadRead(String id) => _change(
    id,
    () => _service.markAsRead(id),
    (t) => t.copyWith(isUnread: false, unreadCount: 0),
  );
  Future<void> markThreadUnread(String id) => _change(
    id,
    () => _service.markAsUnread(id),
    (t) => t.copyWith(
      isUnread: true,
      unreadCount: t.unreadCount > 0 ? t.unreadCount : 1,
    ),
  );
  Future<void> toggleThreadReadStatus(String id) async {
    final thread = state.threads.where((t) => t.id == id).firstOrNull;
    if (thread == null) return;
    if (thread.isUnread) {
      await markThreadRead(id);
    } else {
      await markThreadUnread(id);
    }
  }

  Future<void> deleteConversation(String id) =>
      _change(id, () => _service.deleteThread(id), null);
}

final messagesViewModelProvider =
    NotifierProvider<MessagesViewModel, MessagesState>(MessagesViewModel.new);
