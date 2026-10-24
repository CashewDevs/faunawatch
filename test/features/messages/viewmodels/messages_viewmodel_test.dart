import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/viewmodels/messages_viewmodel.dart';

class MockMessagesService implements MessagesService {
  @override
  Future<List<MessageThread>> fetchMessageThreads() async {
    return const [
      MessageThread(
        id: 'thread-1',
        senderName: 'Ranger Dave',
        lastMessage: 'Eagle spotted',
        timestamp: '10m',
        isUnread: false,
      ),
      MessageThread(
        id: 'thread-2',
        senderName: 'Rescue Team',
        lastMessage: 'Owl injured',
        timestamp: 'Now',
        isUnread: true,
      ),
    ];
  }

  @override
  Future<bool> markAsRead(String threadId) async => true;

  @override
  Future<bool> markAsUnread(String threadId) async => true;

  @override
  Future<bool> deleteThread(String threadId) async => true;

  @override
  Future<List<ChatMessage>> fetchChatMessages(String threadId) async =>
      const [];

  @override
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  }) async {
    return ChatMessage(
      id: 'msg-mock',
      text: text,
      isUser: true,
      timestamp: 'Now',
    );
  }
}

void main() {
  group('MessagesViewModel', () {
    test('loads threads on initialization', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);

      final initial = container.read(messagesViewModelProvider);
      expect(initial.isLoading, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(messagesViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.threads.length, 2);
    });

    test('updates filter and search query', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(messagesViewModelProvider.notifier);

      notifier.setFilter(MessagesFilter.unread);
      expect(
        container.read(messagesViewModelProvider).activeFilter,
        MessagesFilter.unread,
      );

      notifier.setSearchQuery('Eagle');
      expect(container.read(messagesViewModelProvider).searchQuery, 'Eagle');
    });

    test('marks thread as read', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);
      container.read(messagesViewModelProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(messagesViewModelProvider.notifier);

      await notifier.markThreadRead('thread-2');
      final updatedThread = container
          .read(messagesViewModelProvider)
          .threads
          .firstWhere((t) => t.id == 'thread-2');

      expect(updatedThread.isUnread, isFalse);
    });

    test('marks thread as unread', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);
      container.read(messagesViewModelProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(messagesViewModelProvider.notifier);

      await notifier.markThreadUnread('thread-1');
      final updatedThread = container
          .read(messagesViewModelProvider)
          .threads
          .firstWhere((t) => t.id == 'thread-1');

      expect(updatedThread.isUnread, isTrue);
    });

    test('toggleThreadReadStatus flips read status', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);
      container.read(messagesViewModelProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(messagesViewModelProvider.notifier);

      await notifier.toggleThreadReadStatus(
        'thread-2',
      ); // was unread, becomes read
      expect(
        container
            .read(messagesViewModelProvider)
            .threads
            .firstWhere((t) => t.id == 'thread-2')
            .isUnread,
        isFalse,
      );

      await notifier.toggleThreadReadStatus('thread-2'); // becomes unread again
      expect(
        container
            .read(messagesViewModelProvider)
            .threads
            .firstWhere((t) => t.id == 'thread-2')
            .isUnread,
        isTrue,
      );
    });

    test('deleteConversation removes thread from list', () async {
      final container = ProviderContainer(
        overrides: [
          messagesServiceProvider.overrideWithValue(MockMessagesService()),
        ],
      );
      addTearDown(container.dispose);
      container.read(messagesViewModelProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(messagesViewModelProvider.notifier);

      await notifier.deleteConversation('thread-1');
      final state = container.read(messagesViewModelProvider);

      expect(state.threads.length, 1);
      expect(state.threads.any((t) => t.id == 'thread-1'), isFalse);
    });
  });
}
