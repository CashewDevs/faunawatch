import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

/// Modal bottom sheet presenting actions for a long-pressed message thread.
class MessageActionSheet extends StatelessWidget {
  const MessageActionSheet({
    super.key,
    required this.thread,
    required this.onToggleRead,
    required this.onDelete,
  });

  final MessageThread thread;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  static Future<void> show({
    required BuildContext context,
    required MessageThread thread,
    required VoidCallback onToggleRead,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => MessageActionSheet(
        thread: thread,
        onToggleRead: onToggleRead,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Conversation summary
            Text(
              thread.senderName,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              thread.lastMessage,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
            const SizedBox(height: 10),

            // Action: Mark as read / unread
            _buildActionTile(
              context: context,
              icon: thread.isUnread
                  ? Icons.check_circle_outline_rounded
                  : Icons.mark_email_unread_outlined,
              label: thread.isUnread ? 'Mark as read' : 'Mark as unread',
              iconColor: AppColors.messagesHeaderBlue,
              textColor: const Color(0xFF1E293B),
              onTap: () {
                Navigator.of(context).pop();
                onToggleRead();
              },
            ),

            // Action: Delete conversation
            _buildActionTile(
              context: context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete conversation',
              iconColor: const Color(0xFFD32F2F),
              textColor: const Color(0xFFD32F2F),
              onTap: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),

            const SizedBox(height: 8),

            // Cancel action
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
