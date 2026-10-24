import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// Interactive filter pills ("All", "Unread") for notifications.
class NotificationsFilterChips extends StatelessWidget {
  const NotificationsFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
  });

  final NotificationsFilter selectedFilter;
  final ValueChanged<NotificationsFilter> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(
          label: 'All',
          filter: NotificationsFilter.all,
          isSelected: selectedFilter == NotificationsFilter.all,
        ),
        const SizedBox(width: 10),
        _buildChip(
          label: 'Unread',
          filter: NotificationsFilter.unread,
          isSelected: selectedFilter == NotificationsFilter.unread,
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required NotificationsFilter filter,
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
            color: isSelected
                ? AppColors.messagesFilterSelected
                : AppColors.messagesFilterUnselected,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
