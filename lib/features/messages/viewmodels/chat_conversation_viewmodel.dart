import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/services/chat_photo_service.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_time.dart';
export 'package:faunawatch/features/messages/models/chat_message.dart';

class ChatConversationViewModel
    extends AutoDisposeFamilyNotifier<ChatConversationState, String> {
  late MessagesService _service;
  int _generation = 0;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _active = true;
  int get sessionRevision => _generation;
  @override
  ChatConversationState build(String arg) {
    _service = ref.watch(messagesServiceProvider);
    final generation = ++_generation;
    _refreshing = false;
    _refreshAgain = false;
    StreamSubscription<void>? subscription;
    Timer? renewal;
    ref.onDispose(() {
      _generation++;
      subscription?.cancel();
      renewal?.cancel();
    });
    Future.microtask(() {
      if (generation != _generation) return;
      try {
        subscription = _service
            .watchConversation(arg)
            .listen(
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
      renewal = Timer.periodic(const Duration(minutes: 30), (_) {
        if (_active) refresh();
      });
      refresh();
    });
    return const ChatConversationState(isLoading: true);
  }

  void setActive(bool active) {
    _active = active;
    if (active) refresh();
  }

  List<ChatMessage> _merge(
    List<ChatMessage> previous,
    List<ChatMessage> incoming,
  ) {
    final byId = {for (final m in previous) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m.copyWith(
        timestamp: chatTime(m.createdAt, fallback: m.timestamp),
      );
    }
    final result = byId.values.toList();
    // Mock fixtures have no server timestamp and retain insertion order.
    if (result.every((m) => m.createdAt != null)) {
      result.sort((a, b) {
        final order = a.createdAt!.compareTo(b.createdAt!);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
    return result;
  }

  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    final generation = _generation;
    try {
      final oldIds = state.messages.map((m) => m.id).toSet();
      var page = await _service.fetchChatMessages(arg);
      if (generation != _generation) return;
      final incoming = [...page];
      final firstPageFull = page.length == MessagesService.pageSize;
      // Catch up after reconnect even when more than one page arrived offline.
      while (oldIds.isNotEmpty &&
          page.length == MessagesService.pageSize &&
          !page.any((m) => oldIds.contains(m.id))) {
        page = await _service.fetchChatMessages(arg, before: page.first);
        if (generation != _generation) return;
        incoming.insertAll(0, page);
      }
      if (generation != _generation) return;
      final wasEmpty = state.messages.isEmpty;
      state = state.copyWith(
        messages: incoming.isEmpty
            ? state.messages
                  .where((message) => !oldIds.contains(message.id))
                  .toList()
            : _merge(state.messages, incoming),
        isLoading: false,
        hasMore: incoming.isEmpty
            ? false
            : wasEmpty
            ? firstPageFull
            : state.hasMore,
        clearError: true,
      );
      if (_active && state.messages.isNotEmpty) {
        if (!await _service.markAsRead(
          arg,
          throughMessageId: state.messages.last.id,
        )) {
          throw StateError('Read status update failed');
        }
      }
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Could not refresh this chat. Check your connection and try again.',
        );
      }
    } finally {
      if (generation == _generation) {
        _refreshing = false;
        if (_refreshAgain) {
          _refreshAgain = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<void> loadOlder() async {
    if (state.isLoadingMore || !state.hasMore || state.messages.isEmpty) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _service.fetchChatMessages(
        arg,
        before: state.messages.first,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        messages: _merge(state.messages, page),
        isLoadingMore: false,
        hasMore: page.length == MessagesService.pageSize,
      );
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isLoadingMore: false,
          error: 'Could not load older messages. Please try again.',
        );
      }
    }
  }

  Future<void> pickPhoto() async {
    if (state.isPickingPhoto || state.isSending) return;
    final generation = _generation;
    final service = ref.read(chatPhotoServiceProvider);
    state = state.copyWith(isPickingPhoto: true, clearError: true);
    try {
      final photo = await service.pickPhoto();
      if (generation == _generation) {
        state = state.copyWith(photo: photo, isPickingPhoto: false);
      }
    } catch (error) {
      if (generation == _generation) {
        state = state.copyWith(
          isPickingPhoto: false,
          error: error is FormatException
              ? error.message
              : 'Could not open this photo. Please try another.',
        );
      }
    }
  }

  void removePhoto() {
    if (!state.isSending) state = state.copyWith(clearPhoto: true);
  }

  Future<void> reloadPhoto(ChatMessage message) async {
    if (message.imagePath == null) return;
    final generation = _generation;
    try {
      final url = await _service.photoUrl(message.imagePath!);
      if (generation == _generation) {
        state = state.copyWith(
          messages: _merge(state.messages, [message.copyWith(imageUrl: url)]),
          clearError: true,
        );
      }
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          error: 'Could not load this photo. Please try again.',
        );
      }
    }
  }

  Future<bool> sendMessage(String text) async {
    if (state.isSending ||
        state.isPickingPhoto ||
        (text.trim().isEmpty && state.photo == null)) {
      return false;
    }
    if (text.trim().length > 4000) {
      state = state.copyWith(
        error: 'Messages can contain up to 4,000 characters.',
      );
      return false;
    }
    final generation = _generation;
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final message = await _service.sendMessage(
        threadId: arg,
        text: text.trim(),
        photo: state.photo,
      );
      if (generation != _generation) return false;
      state = state.copyWith(
        messages: _merge(state.messages, [message]),
        isSending: false,
        clearPhoto: true,
      );
      return true;
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isSending: false,
          error:
              'Message not sent. Your draft is saved here; please try again.',
        );
      }
      return false;
    }
  }
}

final chatConversationViewModelProvider =
    AutoDisposeNotifierProviderFamily<
      ChatConversationViewModel,
      ChatConversationState,
      String
    >(ChatConversationViewModel.new);
