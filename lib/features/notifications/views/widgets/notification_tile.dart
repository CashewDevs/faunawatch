import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// Notification row item widget.
///
/// If [item.isUnread] is true:
/// - Background is styled in [#FFFBE9].
/// - An accent vertical bar [#FECE01] spans the entire height of the left edge.
///
/// Features a circular icon/avatar placeholder [#D9D9D9] as specified.
/// Supports [onTap] to view/mark as read and [onLongPress] to open action options.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isUnread = item.isUnread;

    return Semantics(
      button: true,
      label:
          '${item.title}, ${item.message}, ${item.timestamp}${isUnread ? ', unread' : ''}',
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
                // Left accent bar for new notifications: #FECE01
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
                        // Circular icon placeholder: gray #D9D9D9
                        _buildLeadingIcon(),
                        const SizedBox(width: 14),

                        // Notification details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
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
                                    item.timestamp,
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
                                item.message,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isUnread
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 2,
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

  Widget _buildLeadingIcon() {
    IconData iconData;
    Color iconColor;

    switch (item.type) {
      case NotificationType.sighting:
        iconData = Icons.pets_rounded;
        iconColor = const Color(0xFF1A5DC9);
        break;
      case NotificationType.alert:
        iconData = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFE65100);
        break;
      case NotificationType.community:
        iconData = Icons.verified_outlined;
        iconColor = const Color(0xFF2E7D32);
        break;
      case NotificationType.system:
        iconData = Icons.notifications_none_rounded;
        iconColor = const Color(0xFF005A97);
        break;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.messagesPfpPlaceholder,
        shape: BoxShape.circle,
      ),
      child: item.avatarAsset != null
          ? ClipOval(
              child: Image.asset(
                item.avatarAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(iconData, color: iconColor, size: 26),
              ),
            )
          : Icon(iconData, color: iconColor, size: 26),
    );
  }
}
