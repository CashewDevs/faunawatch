/// Filter criteria for the Messages screen.
enum MessagesFilter { all, unread }

/// Domain model representing a conversation/message thread.
class MessageThread {
  const MessageThread({
    required this.id,
    required this.senderName,
    required this.lastMessage,
    required this.timestamp,
    this.isUnread = false,
    this.avatarAsset,
    this.unreadCount = 0,
  });

  final String id;
  final String senderName;
  final String lastMessage;
  final String timestamp;
  final bool isUnread;
  final String? avatarAsset;
  final int unreadCount;

  MessageThread copyWith({
    String? id,
    String? senderName,
    String? lastMessage,
    String? timestamp,
    bool? isUnread,
    String? avatarAsset,
    int? unreadCount,
  }) {
    return MessageThread(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      isUnread: isUnread ?? this.isUnread,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageThread &&
        other.id == id &&
        other.senderName == senderName &&
        other.lastMessage == lastMessage &&
        other.timestamp == timestamp &&
        other.isUnread == isUnread &&
        other.avatarAsset == avatarAsset &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode => Object.hash(
    id,
    senderName,
    lastMessage,
    timestamp,
    isUnread,
    avatarAsset,
    unreadCount,
  );
}

/// State container for the Messages feature.
class MessagesState {
  const MessagesState({
    this.threads = const [],
    this.activeFilter = MessagesFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
  });

  final List<MessageThread> threads;
  final MessagesFilter activeFilter;
  final String searchQuery;
  final bool isLoading;

  /// Returns threads filtered by [activeFilter] and [searchQuery].
  List<MessageThread> get filteredThreads {
    return threads.where((thread) {
      if (activeFilter == MessagesFilter.unread && !thread.isUnread) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchSender = thread.senderName.toLowerCase().contains(query);
        final matchMessage = thread.lastMessage.toLowerCase().contains(query);
        if (!matchSender && !matchMessage) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  MessagesState copyWith({
    List<MessageThread>? threads,
    MessagesFilter? activeFilter,
    String? searchQuery,
    bool? isLoading,
  }) {
    return MessagesState(
      threads: threads ?? this.threads,
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessagesState &&
        other.threads == threads &&
        other.activeFilter == activeFilter &&
        other.searchQuery == searchQuery &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode =>
      Object.hash(threads, activeFilter, searchQuery, isLoading);
}
