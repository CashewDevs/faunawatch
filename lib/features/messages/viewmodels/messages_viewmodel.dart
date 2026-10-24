import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';

export 'package:faunawatch/features/messages/models/message_thread.dart';

/// Riverpod Notifier managing messages state, search filtering, and read status.
class MessagesViewModel extends Notifier<MessagesState> {
  late final MessagesService _messagesService;

  @override
  MessagesState build() {
    _messagesService = ref.watch(messagesServiceProvider);
    _loadInitialThreads();
    return const MessagesState(isLoading: true);
  }

  Future<void> _loadInitialThreads() async {
    try {
      final threads = await _messagesService.fetchMessageThreads();
      state = state.copyWith(threads: threads, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sets the active filter (All or Unread).
  void setFilter(MessagesFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  /// Updates the query used to filter message threads.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Marks a specific thread as read.
  Future<void> markThreadRead(String threadId) async {
    final updatedThreads = state.threads.map((thread) {
      if (thread.id == threadId) {
        return thread.copyWith(isUnread: false, unreadCount: 0);
      }
      return thread;
    }).toList();

    state = state.copyWith(threads: updatedThreads);
    await _messagesService.markAsRead(threadId);
  }

  /// Marks a specific thread as unread.
  Future<void> markThreadUnread(String threadId) async {
    final updatedThreads = state.threads.map((thread) {
      if (thread.id == threadId) {
        return thread.copyWith(
          isUnread: true,
          unreadCount: thread.unreadCount > 0 ? thread.unreadCount : 1,
        );
      }
      return thread;
    }).toList();

    state = state.copyWith(threads: updatedThreads);
    await _messagesService.markAsUnread(threadId);
  }

  /// Toggles read/unread status for a specific thread.
  Future<void> toggleThreadReadStatus(String threadId) async {
    final thread = state.threads.firstWhere(
      (t) => t.id == threadId,
      orElse: () => const MessageThread(
        id: '',
        senderName: '',
        lastMessage: '',
        timestamp: '',
      ),
    );
    if (thread.id.isEmpty) return;

    if (thread.isUnread) {
      await markThreadRead(threadId);
    } else {
      await markThreadUnread(threadId);
    }
  }

  /// Deletes an entire conversation thread.
  Future<void> deleteConversation(String threadId) async {
    final updatedThreads = state.threads
        .where((thread) => thread.id != threadId)
        .toList();

    state = state.copyWith(threads: updatedThreads);
    await _messagesService.deleteThread(threadId);
  }
}

/// Riverpod provider exposing [MessagesViewModel] and [MessagesState].
final messagesViewModelProvider =
    NotifierProvider<MessagesViewModel, MessagesState>(MessagesViewModel.new);
