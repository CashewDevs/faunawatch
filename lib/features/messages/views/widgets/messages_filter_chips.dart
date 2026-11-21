import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

/// Interactive filter pills ("All", "Unread") for message threads.
class MessagesFilterChips extends StatelessWidget {
  const MessagesFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
  });

  final MessagesFilter selectedFilter;
  final ValueChanged<MessagesFilter> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _buildChip(
          context: context,
          isDark: isDark,
          label: 'All',
          filter: MessagesFilter.all,
          isSelected: selectedFilter == MessagesFilter.all,
        ),
        const SizedBox(width: 10),
        _buildChip(
          context: context,
          isDark: isDark,
          label: 'Unread',
          filter: MessagesFilter.unread,
          isSelected: selectedFilter == MessagesFilter.unread,
        ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required bool isDark,
    required String label,
    required MessagesFilter filter,
    required bool isSelected,
  }) {
    return Semantics(
      button: true,
      label: 'Filter $label',
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onSelectFilter(filter),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? (isSelected
                      ? AppPaletteColors.of(context).darkFilterSelected
                      : AppColors.darkSurface)
                : (isSelected
                      ? AppPaletteColors.of(context).messagesFilterSelected
                      : AppPaletteColors.of(context).messagesFilterUnselected),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: isDark
                  ? (isSelected
                        ? AppColors.darkTextPrimary
                        : AppColors.darkTextBody)
                  : Colors.black87,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
