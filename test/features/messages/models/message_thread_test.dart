import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

void main() {
  group('MessageThread', () {
    test('supports value equality and copyWith', () {
      const thread1 = MessageThread(
        id: '1',
        senderName: 'Alice',
        lastMessage: 'Hello',
        timestamp: '1m',
        isUnread: true,
      );

      final thread2 = thread1.copyWith(isUnread: false);

      expect(thread1 == thread2, isFalse);
      expect(thread2.isUnread, isFalse);
      expect(thread2.senderName, 'Alice');

      final thread1Clone = thread1.copyWith();
      expect(thread1 == thread1Clone, isTrue);
    });
  });

  group('MessagesState', () {
    const threadRead = MessageThread(
      id: '1',
      senderName: 'Ranger Dave',
      lastMessage: 'Report logged',
      timestamp: '1h',
      isUnread: false,
    );

    const threadUnread = MessageThread(
      id: '2',
      senderName: 'Wildlife Rescue',
      lastMessage: 'Urgent situation',
      timestamp: 'Just now',
      isUnread: true,
    );

    test('filteredThreads filters by unread activeFilter', () {
      const stateAll = MessagesState(
        threads: [threadRead, threadUnread],
        activeFilter: MessagesFilter.all,
      );
      expect(stateAll.filteredThreads.length, 2);

      const stateUnread = MessagesState(
        threads: [threadRead, threadUnread],
        activeFilter: MessagesFilter.unread,
      );
      expect(stateUnread.filteredThreads.length, 1);
      expect(stateUnread.filteredThreads.first.id, '2');
    });

    test(
      'filteredThreads filters by search query matching sender or message',
      () {
        const state = MessagesState(
          threads: [threadRead, threadUnread],
          searchQuery: 'Rescue',
        );
        expect(state.filteredThreads.length, 1);
        expect(state.filteredThreads.first.id, '2');

        const stateMsg = MessagesState(
          threads: [threadRead, threadUnread],
          searchQuery: 'Report',
        );
        expect(stateMsg.filteredThreads.length, 1);
        expect(stateMsg.filteredThreads.first.id, '1');
      },
    );
  });
}
