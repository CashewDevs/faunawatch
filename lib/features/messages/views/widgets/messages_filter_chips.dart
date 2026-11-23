import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/messages/models/message_thread.dart';

/// Interactive filter pills ("All", "Unread") with a selected blue stroke,
/// paired with a sort/filter dropdown button on the opposite side of the row.
class MessagesFilterChips extends StatelessWidget {
  const MessagesFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
    this.selectedSortOrder = MessagesSortOrder.newest,
    this.onSelectSortOrder,
  });

  final MessagesFilter selectedFilter;
  final ValueChanged<MessagesFilter> onSelectFilter;
  final MessagesSortOrder selectedSortOrder;
  final ValueChanged<MessagesSortOrder>? onSelectSortOrder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteColors.of(context);
    final strokeColor = isDark
        ? palette.darkAccentBlue
        : palette.messagesSearchBorder;

    return Row(
      children: [
        _buildChip(
          context: context,
          isDark: isDark,
          palette: palette,
          strokeColor: strokeColor,
          label: 'All',
          filter: MessagesFilter.all,
          isSelected: selectedFilter == MessagesFilter.all,
        ),
        const SizedBox(width: 10),
        _buildChip(
          context: context,
          isDark: isDark,
          palette: palette,
          strokeColor: strokeColor,
          label: 'Unread',
          filter: MessagesFilter.unread,
          isSelected: selectedFilter == MessagesFilter.unread,
        ),
        const Spacer(),
        if (onSelectSortOrder != null)
          _SortFilterDropdown(
            isDark: isDark,
            palette: palette,
            strokeColor: strokeColor,
            selectedSortOrder: selectedSortOrder,
            onSelected: onSelectSortOrder!,
          ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required bool isDark,
    required AppPaletteColors palette,
    required Color strokeColor,
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
                      ? palette.darkFilterSelected
                      : AppColors.darkSurface)
                : (isSelected
                      ? palette.messagesFilterSelected
                      : palette.messagesFilterUnselected),
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: strokeColor, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
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

class _SortFilterDropdown extends StatelessWidget {
  const _SortFilterDropdown({
    required this.isDark,
    required this.palette,
    required this.strokeColor,
    required this.selectedSortOrder,
    required this.onSelected,
  });

  final bool isDark;
  final AppPaletteColors palette;
  final Color strokeColor;
  final MessagesSortOrder selectedSortOrder;
  final ValueChanged<MessagesSortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark
        ? palette.darkFilterSelected
        : palette.messagesFilterSelected;
    final menuBg = isDark
        ? AppColors.darkSurface
        : palette.messagesFilterUnselected;
    final labelColor = isDark
        ? AppColors.darkTextPrimary
        : palette.messagesHeaderBlue;
    final buttonLabel = selectedSortOrder == MessagesSortOrder.newest
        ? 'Filter'
        : selectedSortOrder.label;

    return PopupMenuButton<MessagesSortOrder>(
      key: const ValueKey('messages_sort_filter_button'),
      tooltip: 'Sort messages',
      onSelected: onSelected,
      offset: const Offset(0, 38),
      elevation: 4,
      color: menuBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: strokeColor, width: 1.5),
      ),
      itemBuilder: (context) => [
        for (final option in MessagesSortOrder.values)
          PopupMenuItem<MessagesSortOrder>(
            value: option,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  option.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: selectedSortOrder == option
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: labelColor,
                  ),
                ),
                if (selectedSortOrder == option) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check_rounded, size: 18, color: strokeColor),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        key: const ValueKey('messages_sort_filter_pill'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strokeColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16, color: labelColor),
            const SizedBox(width: 6),
            Text(
              buttonLabel,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: labelColor,
            ),
          ],
        ),
      ),
    );
  }
}
