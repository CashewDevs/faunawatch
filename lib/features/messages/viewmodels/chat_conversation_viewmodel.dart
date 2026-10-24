import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';

export 'package:faunawatch/features/messages/models/chat_message.dart';

/// Riverpod family notifier managing conversation messages for a specific thread ID.
class ChatConversationViewModel
    extends AutoDisposeFamilyNotifier<ChatConversationState, String> {
  late final MessagesService _messagesService;

  @override
  ChatConversationState build(String arg) {
    _messagesService = ref.watch(messagesServiceProvider);
    _loadMessages(arg);
    return const ChatConversationState(isLoading: true);
  }

  Future<void> _loadMessages(String threadId) async {
    try {
      final messages = await _messagesService.fetchChatMessages(threadId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sends a new message in the conversation.
  Future<void> sendMessage(String text, {String? imageUrl}) async {
    if (text.trim().isEmpty && imageUrl == null) return;

    final newMsg = await _messagesService.sendMessage(
      threadId: arg,
      text: text.trim(),
      imageUrl: imageUrl,
    );

    state = state.copyWith(messages: [...state.messages, newMsg]);
  }
}

/// Riverpod provider family exposing [ChatConversationViewModel] by threadId.
final chatConversationViewModelProvider =
    AutoDisposeNotifierProviderFamily<
      ChatConversationViewModel,
      ChatConversationState,
      String
    >(ChatConversationViewModel.new);
