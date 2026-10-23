import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

/// Contract for fetching and interacting with message threads.
abstract interface class MessagesService {
  Future<List<MessageThread>> fetchMessageThreads();
  Future<bool> markAsRead(String threadId);
  Future<bool> markAsUnread(String threadId);
  Future<bool> deleteThread(String threadId);
  Future<List<ChatMessage>> fetchChatMessages(String threadId);
  Future<ChatMessage> sendMessage({
    required String threadId,
    required String text,
    String? imageUrl,
  });
}

/// Default implementation providing mock fauna message threads.
///
/// Formatted according to the design specification:
/// 5 initial conversations, with thread #2 flagged as unread (yellow accent).
class FaunaMessagesService implements MessagesService {
  const FaunaMessagesService();

  @override
  Future<List<MessageThread>> fetchMessageThreads() async {
    return const [
      MessageThread(
        id: 'thread-1',
        senderName: 'Ranger Dave',
        lastMessage: 'Spotted a bald eagle near Ridge Pass! Photo uploaded.',
        timestamp: '10:42 AM',
        isUnread: false,
        avatarAsset: AppAssets.avatarTweety,
      ),
      MessageThread(
        id: 'thread-2',
        senderName: 'Wildlife Rescue Team',
        lastMessage:
            'Urgent: Injured barn owl reported near Sector 3 Pine Trail.',
        timestamp: 'Just now',
        isUnread: true,
        unreadCount: 1,
        avatarAsset: AppAssets.avatarBunny,
      ),
      MessageThread(
        id: 'thread-3',
        senderName: 'Alex Rivera (Spotter)',
        lastMessage:
            'Thanks for confirming the monarch butterfly migration data!',
        timestamp: 'Yesterday',
        isUnread: false,
        avatarAsset: AppAssets.avatarPanda,
      ),
      MessageThread(
        id: 'thread-4',
        senderName: 'Dr. Helena Vance',
        lastMessage:
            'The biodiversity quarterly report has been updated for our zone.',
        timestamp: '2d ago',
        isUnread: false,
        avatarAsset: AppAssets.avatarGarfield,
      ),
      MessageThread(
        id: 'thread-5',
        senderName: 'FaunaWatch Community',
        lastMessage:
            'Welcome to the network! Check out active sightings in your area.',
        timestamp: '5d ago',
        isUnread: false,
        avatarAsset: AppAssets.avatarIce,
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
  Future<List<ChatMessage>> fetchChatMessages(String threadId) async {
    return const [
      ChatMessage(
        id: 'msg-1',
        text: 'Hello! Have you confirmed the coordinates for the sighting?',
        isUser: false,
        timestamp: '10:30 AM',
      ),
      ChatMessage(
        id: 'msg-2',
        text: 'Yes, just uploaded the map pin near Ridge Pass.',
        isUser: true,
        timestamp: '10:32 AM',
      ),
      ChatMessage(
        id: 'msg-3',
        text: 'Great, the team is heading there now.',
        isUser: false,
        timestamp: '10:33 AM',
      ),
      ChatMessage(
        id: 'msg-4',
        text: 'Here is the preliminary photo taken from the observation deck.',
        isUser: true,
        timestamp: '10:35 AM',
      ),
      ChatMessage(
        id: 'msg-5',
        text: 'Please keep us posted once you reach the sector!',
        isUser: true,
        timestamp: '10:36 AM',
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
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: 'Just now',
      imageUrl: imageUrl,
    );
  }
}

/// Riverpod provider exposing [MessagesService].
final messagesServiceProvider = Provider<MessagesService>((ref) {
  return const FaunaMessagesService();
});
