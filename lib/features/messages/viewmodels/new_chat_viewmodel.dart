import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/models/new_chat_state.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';

class NewChatViewModel extends AutoDisposeNotifier<NewChatState> {
  late MessagesService _service;
  int _generation = 0;
  int _search = 0;
  Timer? _suggestionTimer;
  static const suggestionDelay = Duration(milliseconds: 300);
  @override
  NewChatState build() {
    _service = ref.watch(messagesServiceProvider);
    _suggestionTimer?.cancel();
    _generation++;
    ref.onDispose(() {
      _generation++;
      _suggestionTimer?.cancel();
    });
    return const NewChatState();
  }

  void onQueryChanged(String query) {
    if (state.openingUserId != null) return;
    _suggestionTimer?.cancel();
    // Invalidate in-flight responses immediately, before the next request.
    _search++;
    if (query.trim().length < 2) {
      state = const NewChatState();
      return;
    }
    state = const NewChatState(isSearching: true);
    _suggestionTimer = Timer(suggestionDelay, () => unawaited(search(query)));
  }

  Future<void> search(String query) async {
    if (state.openingUserId != null) return;
    _suggestionTimer?.cancel();
    final request = ++_search;
    final generation = _generation;
    if (query.trim().length < 2) {
      state = const NewChatState(error: 'Enter at least two characters.');
      return;
    }
    state = const NewChatState(isSearching: true);
    try {
      final users = await _service.searchUsers(query);
      if (generation == _generation && request == _search) {
        state = NewChatState(users: users, hasSearched: true);
      }
    } catch (_) {
      if (generation == _generation && request == _search) {
        state = const NewChatState(
          error: 'Could not search users. Please try again.',
        );
      }
    }
  }

  Future<MessageThread?> open(ChatUser user) async {
    if (state.openingUserId != null || state.isSearching) return null;
    final generation = _generation;
    state = NewChatState(
      users: state.users,
      openingUserId: user.id,
      hasSearched: true,
    );
    try {
      final thread = await _service.openChat(user);
      if (generation != _generation) return null;
      state = NewChatState(users: state.users, hasSearched: true);
      return thread;
    } catch (_) {
      if (generation == _generation) {
        state = NewChatState(
          users: state.users,
          hasSearched: true,
          error: 'Could not start this chat. Please try again.',
        );
      }
      return null;
    }
  }
}

final newChatViewModelProvider =
    AutoDisposeNotifierProvider<NewChatViewModel, NewChatState>(
      NewChatViewModel.new,
    );
