import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('supports value equality and copyWith', () {
      const msg1 = ChatMessage(
        id: 'msg-1',
        text: 'Hello',
        isUser: true,
        timestamp: '10:00 AM',
      );

      final msg2 = msg1.copyWith(text: 'Updated');

      expect(msg1 == msg2, isFalse);
      expect(msg2.text, 'Updated');
      expect(msg2.isUser, isTrue);

      final msg1Clone = msg1.copyWith();
      expect(msg1 == msg1Clone, isTrue);
    });
  });

  group('ChatConversationState', () {
    test('supports copyWith and equality', () {
      const state1 = ChatConversationState(isLoading: true);
      const msg = ChatMessage(
        id: '1',
        text: 'Test',
        isUser: false,
        timestamp: 'Now',
      );

      final state2 = state1.copyWith(isLoading: false, messages: [msg]);

      expect(state2.isLoading, isFalse);
      expect(state2.messages.length, 1);
      expect(state1 == state2, isFalse);
    });
  });
}
