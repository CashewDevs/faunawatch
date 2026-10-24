/// Model representing a single message inside a conversation thread.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });

  final String id;
  final String text;
  final bool isUser;
  final String timestamp;
  final String? imageUrl;

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? timestamp,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.text == text &&
        other.isUser == isUser &&
        other.timestamp == timestamp &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(id, text, isUser, timestamp, imageUrl);
}

/// State container for an active chat conversation.
class ChatConversationState {
  const ChatConversationState({
    this.messages = const [],
    this.isLoading = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;

  ChatConversationState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatConversationState &&
        other.messages == messages &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(messages, isLoading);
}
