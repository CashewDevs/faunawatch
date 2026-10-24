import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Top header for the chat conversation view.
///
/// Features:
/// - Header background in [#FFFBE9]
/// - Back chevron button utilizing `left.webp`
/// - Circular profile picture placeholder [#D9D9D9]
/// - Username rendered in DM Sans extrabold
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.username,
    this.avatarAsset,
    required this.onBack,
  });

  final String username;
  final String? avatarAsset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chatHeaderBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Chevron left back button: left.webp
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Image.asset(
                      AppAssets.backArrowIcon,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.chevron_left_rounded,
                        size: 36,
                        color: AppColors.messagesHeaderBlue,
                      ),
                    ),
                  ),
                ),
              ),

              // Gray circular profile picture placeholder
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.messagesPfpPlaceholder,
                  shape: BoxShape.circle,
                ),
                child: avatarAsset != null
                    ? ClipOval(
                        child: Image.asset(
                          avatarAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Username in DM Sans extrabold
              Expanded(
                child: Text(
                  username,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
