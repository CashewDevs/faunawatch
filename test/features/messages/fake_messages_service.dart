import 'package:faunawatch/features/messages/services/messages_service.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';
export 'package:faunawatch/features/messages/models/chat_photo.dart';

/// Optional operations shared by the original UI fixtures; no network access.
abstract class FakeMessagesService implements MessagesService {
  @override
  Future<String> photoUrl(String path) async =>
      'https://chat-tests.invalid/photo';
  @override
  Stream<void> watchInbox() => const Stream.empty();
  @override
  Stream<void> watchConversation(String threadId) => const Stream.empty();
  @override
  Future<List<ChatUser>> searchUsers(String query) async => [];
  @override
  Future<MessageThread> openChat(ChatUser user) async => MessageThread(
    id: 'new-thread',
    senderName: user.name,
    lastMessage: '',
    timestamp: '',
  );
}
