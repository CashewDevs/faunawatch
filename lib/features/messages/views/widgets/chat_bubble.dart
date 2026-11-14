import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/chat_message.dart';

/// Single speech bubble inside the chat conversation.
///
/// Implements design specifications:
/// - Current user: horizontal gradient from 0% [#A4DDFF] to 100% [#DCF2FF]
/// - Other user: horizontal gradient from 0% [#D5D5D5] to 100% [#E8E8E8]
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.showTail = true,
    this.onReloadPhoto,
  });

  final ChatMessage message;
  final bool showTail;
  final VoidCallback? onReloadPhoto;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradient = isUser
        ? LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 1.0],
            colors: isDark
                ? [
                    AppPaletteColors.of(
                      context,
                    ).darkChatUserBubbleGradientStart,
                    AppPaletteColors.of(context).darkChatUserBubbleGradientEnd,
                  ]
                : [
                    AppPaletteColors.of(context).chatUserBubbleGradientStart,
                    AppPaletteColors.of(context).chatUserBubbleGradientEnd,
                  ],
          )
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 1.0],
            colors: isDark
                ? const [
                    AppColors.darkChatOtherBubbleGradientStart,
                    AppColors.darkChatOtherBubbleGradientEnd,
                  ]
                : const [
                    AppColors.chatOtherBubbleGradientStart,
                    AppColors.chatOtherBubbleGradientEnd,
                  ],
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
          minWidth: 100,
          minHeight: 48,
        ),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: showTail
              ? BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 3),
                  bottomRight: Radius.circular(isUser ? 3 : 16),
                )
              : BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message.imageUrl!,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => TextButton(
                    onPressed: onReloadPhoto,
                    child: const Text('Reload photo'),
                  ),
                ),
              )
            else if (message.imagePath != null)
              TextButton(
                onPressed: onReloadPhoto,
                child: const Text('Reload photo'),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF0F1A3C),
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              message.timestamp,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.darkTextPrimary.withValues(alpha: 0.7)
                    : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
