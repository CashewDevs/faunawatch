import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

/// Message row item.
///
/// If [thread.isUnread] is true:
/// - Background is styled in [#FFFBE9].
/// - An accent vertical bar [#FECE01] spans the entire height of the left edge.
///
/// Features a circular profile picture placeholder [#D9D9D9] as specified.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.thread,
    required this.onTap,
    this.onLongPress,
  });

  final MessageThread thread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isUnread = thread.isUnread;

    return Semantics(
      button: true,
      label:
          '${thread.senderName}, ${thread.lastMessage}, ${thread.timestamp}${isUnread ? ', new message' : ''}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: isUnread
              ? AppColors.messagesUnreadBackground
              : Colors.transparent,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar for new messages: #FECE01
                if (isUnread)
                  Container(width: 8, color: AppColors.messagesUnreadBar)
                else
                  const SizedBox(width: 8),

                // Main row content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile picture circle: gray #D9D9D9
                        _buildProfilePicture(),
                        const SizedBox(width: 14),

                        // Message details: Sender name & message preview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.senderName,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isUnread
                                            ? Colors.black87
                                            : const Color(0xFF263238),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    thread.timestamp,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isUnread
                                          ? AppColors.messagesHeaderBlue
                                          : const Color(0xFF90A4AE),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                thread.lastMessage,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isUnread
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.messagesPfpPlaceholder,
        shape: BoxShape.circle,
      ),
      child: thread.avatarAsset != null
          ? ClipOval(
              child: Image.asset(
                thread.avatarAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          : null,
    );
  }
}
