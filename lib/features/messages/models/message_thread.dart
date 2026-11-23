/// Filter criteria for the Messages screen.
enum MessagesFilter { all, unread }

/// Sort order options for the Messages screen dropdown.
enum MessagesSortOrder {
  newest('Newest'),
  oldest('Oldest'),
  alphabeticalAZ('A–Z'),
  alphabeticalZA('Z–A'),
  unreadFirst('Unread first');

  const MessagesSortOrder(this.label);

  final String label;
}

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
    this.otherUserId,
    this.avatarUrl,
    this.lastMessageAt,
  });

  final String id;
  final String senderName;
  final String lastMessage;
  final String timestamp;
  final bool isUnread;
  final String? avatarAsset;
  final int unreadCount;
  final String? otherUserId;
  final String? avatarUrl;
  final DateTime? lastMessageAt;

  factory MessageThread.fromJson(Map<String, dynamic> row) => MessageThread(
    id: row['id'] as String,
    senderName: row['sender_name'] as String,
    lastMessage: row['last_message'] as String? ?? '',
    timestamp: '',
    otherUserId: row['other_user_id'] as String,
    lastMessageAt: DateTime.parse(row['last_message_at'] as String),
    isUnread: row['is_unread'] as bool? ?? false,
    unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
  );

  MessageThread copyWith({
    String? id,
    String? senderName,
    String? lastMessage,
    String? timestamp,
    bool? isUnread,
    String? avatarAsset,
    int? unreadCount,
    String? avatarUrl,
  }) {
    return MessageThread(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      isUnread: isUnread ?? this.isUnread,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUserId: otherUserId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageAt: lastMessageAt,
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
        other.unreadCount == unreadCount &&
        other.otherUserId == otherUserId &&
        other.avatarUrl == avatarUrl &&
        other.lastMessageAt == lastMessageAt;
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
    otherUserId,
    avatarUrl,
    lastMessageAt,
  );
}

/// State container for the Messages feature.
class MessagesState {
  const MessagesState({
    this.threads = const [],
    this.activeFilter = MessagesFilter.all,
    this.sortOrder = MessagesSortOrder.newest,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  final List<MessageThread> threads;
  final MessagesFilter activeFilter;
  final MessagesSortOrder? sortOrder;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  /// Effective sort order (safe even across hot-reloaded instances).
  MessagesSortOrder get effectiveSortOrder =>
      sortOrder ?? MessagesSortOrder.newest;

  /// Returns threads filtered by [activeFilter] and [searchQuery], then sorted
  /// according to [effectiveSortOrder].
  List<MessageThread> get filteredThreads {
    final indexed = <(int, MessageThread)>[];
    for (var i = 0; i < threads.length; i++) {
      final thread = threads[i];
      if (activeFilter == MessagesFilter.unread && !thread.isUnread) {
        continue;
      }
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchSender = thread.senderName.toLowerCase().contains(query);
        final matchMessage = thread.lastMessage.toLowerCase().contains(query);
        if (!matchSender && !matchMessage) {
          continue;
        }
      }
      indexed.add((i, thread));
    }

    int compareNewest((int, MessageThread) a, (int, MessageThread) b) {
      final aAt = a.$2.lastMessageAt;
      final bAt = b.$2.lastMessageAt;
      if (aAt != null && bAt != null) {
        final cmp = bAt.compareTo(aAt);
        if (cmp != 0) return cmp;
      }
      return a.$1.compareTo(b.$1);
    }

    switch (effectiveSortOrder) {
      case MessagesSortOrder.newest:
        indexed.sort(compareNewest);
      case MessagesSortOrder.oldest:
        indexed.sort((a, b) {
          final aAt = a.$2.lastMessageAt;
          final bAt = b.$2.lastMessageAt;
          if (aAt != null && bAt != null) {
            final cmp = aAt.compareTo(bAt);
            if (cmp != 0) return cmp;
          }
          return b.$1.compareTo(a.$1);
        });
      case MessagesSortOrder.alphabeticalAZ:
        indexed.sort((a, b) {
          final cmp = a.$2.senderName.toLowerCase().compareTo(
            b.$2.senderName.toLowerCase(),
          );
          return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
        });
      case MessagesSortOrder.alphabeticalZA:
        indexed.sort((a, b) {
          final cmp = b.$2.senderName.toLowerCase().compareTo(
            a.$2.senderName.toLowerCase(),
          );
          return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
        });
      case MessagesSortOrder.unreadFirst:
        indexed.sort((a, b) {
          if (a.$2.isUnread != b.$2.isUnread) {
            return a.$2.isUnread ? -1 : 1;
          }
          return compareNewest(a, b);
        });
    }

    return [for (final item in indexed) item.$2];
  }

  MessagesState copyWith({
    List<MessageThread>? threads,
    MessagesFilter? activeFilter,
    MessagesSortOrder? sortOrder,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MessagesState(
      threads: threads ?? this.threads,
      activeFilter: activeFilter ?? this.activeFilter,
      sortOrder: sortOrder ?? effectiveSortOrder,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessagesState &&
        other.threads == threads &&
        other.activeFilter == activeFilter &&
        other.effectiveSortOrder == effectiveSortOrder &&
        other.searchQuery == searchQuery &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    threads,
    activeFilter,
    effectiveSortOrder,
    searchQuery,
    isLoading,
    error,
  );
}
