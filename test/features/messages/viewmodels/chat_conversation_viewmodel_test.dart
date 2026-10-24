import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/viewmodels/chat_conversation_viewmodel.dart';

class MockChatMessagesService implements MessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async => const [];

  @override
  Future<bool> markAsRead(String threadId) async => true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<List<ChatMessage>> fetchChatMessages(String threadId) async {
    return const [
      ChatMessage(
        id: 'msg-1',
        text: 'Initial message',
        isUser: false,
        timestamp: '10:00 AM',
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  }) async {
    return ChatMessage(
      id: 'msg-new',
      text: text,
      isUser: true,
      timestamp: 'Just now',
      imageUrl: imageUrl,
    );
  }
}

void main() {
  group('ChatConversationViewModel', () {
    test('loads conversation messages on build', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockChatMessagesService()),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        chatConversationViewModelProvider('thread-1'),
        (_, _) {},
      );
      await pumpEventQueue();

      final state = container.read(
        chatConversationViewModelProvider('thread-1'),
      );
      expect(state.isLoading, isFalse);
      expect(state.messages.length, 1);
      expect(state.messages.first.text, 'Initial message');
      sub.close();
    });

    test('sendMessage appends new message to state', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockChatMessagesService()),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        chatConversationViewModelProvider('thread-1'),
        (_, _) {},
      );
      await pumpEventQueue();

      final notifier = container.read(
        chatConversationViewModelProvider('thread-1').notifier,
      );
      await notifier.sendMessage('Hello from user');

      final state = container.read(
        chatConversationViewModelProvider('thread-1'),
      );
      expect(state.messages.length, 2);
      expect(state.messages.last.text, 'Hello from user');
      expect(state.messages.last.isUser, isTrue);
      sub.close();
    });
  });
}
