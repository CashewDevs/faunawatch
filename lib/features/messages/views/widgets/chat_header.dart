import 'package:faunawatch/core/theme/app_palette_colors.dart';
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
    this.avatarUrl,
    required this.onBack,
  });

  final String username;
  final String? avatarAsset;
  final String? avatarUrl;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.chatHeaderBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                      color: isDark
                          ? AppPaletteColors.of(context).darkAccentBlue
                          : null,
                      colorBlendMode: isDark ? BlendMode.srcIn : null,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.chevron_left_rounded,
                        size: 36,
                        color: isDark
                            ? AppPaletteColors.of(context).darkAccentBlue
                            : AppPaletteColors.of(context).messagesHeaderBlue,
                      ),
                    ),
                  ),
                ),
              ),

              // Gray circular profile picture placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.messagesPfpPlaceholder,
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
                    : avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl!,
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
                    color: isDark ? AppColors.darkTextPrimary : Colors.black87,
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
