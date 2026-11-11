import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Search input bar featuring `where.webp` icon and a bright blue stroke.
class MessagesSearchBar extends StatelessWidget {
  const MessagesSearchBar({
    super.key,
    required this.onChanged,
    this.controller,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? AppColors.darkAccentBlue
              : AppColors.messagesSearchBorder,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Image.asset(
            AppAssets.whereIcon,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            color: isDark ? AppColors.darkAccentBlue : null,
            colorBlendMode: isDark ? BlendMode.srcIn : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: isDark
                  ? AppColors.darkAccentBlue
                  : AppColors.messagesHeaderBlue,
              style: GoogleFonts.dmSans(
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: GoogleFonts.dmSans(
                  color: isDark ? AppColors.darkTextSecondary : Colors.black38,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
