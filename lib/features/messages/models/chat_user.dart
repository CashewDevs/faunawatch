/// Community identity exposed by user search; never includes email or location.
class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    this.avatarPath,
    this.avatarAsset,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String? avatarPath;
  final String? avatarAsset;
  final String? avatarUrl;

  ChatUser copyWith({String? avatarAsset, String? avatarUrl}) => ChatUser(
    id: id,
    name: name,
    avatarPath: avatarPath,
    avatarAsset: avatarAsset ?? this.avatarAsset,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  factory ChatUser.fromJson(Map<String, dynamic> row) => ChatUser(
    id: row['id'] as String,
    name:
        [row['username'], row['full_name'], row['display_name']]
            .whereType<String>()
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .firstOrNull ??
        'FaunaWatch user',
    avatarPath: row['avatar_path'] as String?,
  );
}
