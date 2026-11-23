import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';

/// Search input bar featuring a crisp vector search icon and a bright blue stroke.
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
    final palette = AppPaletteColors.of(context);
    final accentColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesHeaderBlue;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? palette.darkAccentBlue : palette.messagesSearchBorder,
          width: 2.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: accentColor,
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
