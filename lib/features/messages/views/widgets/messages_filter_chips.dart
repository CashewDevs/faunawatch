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
    return Row(
      children: [
        _buildChip(
          label: 'All',
          filter: MessagesFilter.all,
          isSelected: selectedFilter == MessagesFilter.all,
        ),
        const SizedBox(width: 10),
        _buildChip(
          label: 'Unread',
          filter: MessagesFilter.unread,
          isSelected: selectedFilter == MessagesFilter.unread,
        ),
      ],
    );
  }

  Widget _buildChip({
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
