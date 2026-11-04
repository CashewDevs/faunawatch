import 'package:faunawatch/features/messages/models/chat_user.dart';

class NewChatState {
  const NewChatState({
    this.users = const [],
    this.isSearching = false,
    this.openingUserId,
    this.error,
    this.hasSearched = false,
  });
  final List<ChatUser> users;
  final bool isSearching;
  final String? openingUserId;
  final String? error;
  final bool hasSearched;
}
