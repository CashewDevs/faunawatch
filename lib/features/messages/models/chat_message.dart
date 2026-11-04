import 'package:faunawatch/features/messages/models/chat_photo.dart';

/// Model representing a single message inside a conversation thread.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    this.createdAt,
    this.imagePath,
  });

  final String id;
  final String text;
  final bool isUser;
  final String timestamp;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? imagePath;

  factory ChatMessage.fromJson(Map<String, dynamic> row, String userId) =>
      ChatMessage(
        id: row['id'] as String,
        text: row['body'] as String? ?? '',
        isUser: row['sender_id'] == userId,
        timestamp: '',
        createdAt: DateTime.parse(row['created_at'] as String),
        imagePath: row['image_path'] as String?,
      );

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
      createdAt: createdAt,
      imagePath: imagePath,
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
        other.imageUrl == imageUrl &&
        other.createdAt == createdAt &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode =>
      Object.hash(id, text, isUser, timestamp, imageUrl, createdAt, imagePath);
}

/// State container for an active chat conversation.
class ChatConversationState {
  const ChatConversationState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isPickingPhoto = false,
    this.error,
    this.photo,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isPickingPhoto;
  final String? error;
  final ChatPhoto? photo;
  final bool hasMore;
  final bool isLoadingMore;

  ChatConversationState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isPickingPhoto,
    String? error,
    bool clearError = false,
    ChatPhoto? photo,
    bool clearPhoto = false,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ChatConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isPickingPhoto: isPickingPhoto ?? this.isPickingPhoto,
      error: clearError ? null : error ?? this.error,
      photo: clearPhoto ? null : photo ?? this.photo,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatConversationState &&
        other.messages == messages &&
        other.isLoading == isLoading &&
        other.isSending == isSending &&
        other.isPickingPhoto == isPickingPhoto &&
        other.error == error &&
        other.photo == photo &&
        other.hasMore == hasMore &&
        other.isLoadingMore == isLoadingMore;
  }

  @override
  int get hashCode => Object.hash(
    messages,
    isLoading,
    isSending,
    isPickingPhoto,
    error,
    photo,
    hasMore,
    isLoadingMore,
  );
}
