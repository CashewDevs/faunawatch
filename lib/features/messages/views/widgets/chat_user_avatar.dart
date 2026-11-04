import 'package:flutter/material.dart';
import 'package:faunawatch/features/messages/models/chat_user.dart';

/// Search result avatar, falling back to the person icon for missing images.
class ChatUserAvatar extends StatelessWidget {
  const ChatUserAvatar({super.key, required this.user});
  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.person_outline);
    final Widget photo;
    if (user.avatarAsset != null) {
      photo = Image.asset(
        user.avatarAsset!,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (user.avatarUrl != null) {
      photo = Image.network(
        user.avatarUrl!,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      photo = fallback;
    }
    return CircleAvatar(
      radius: 20,
      child: ClipOval(child: SizedBox.square(dimension: 40, child: photo)),
    );
  }
}
