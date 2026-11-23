import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/notifications/models/notification_item.dart';

/// Interactive filter pills ("All", "Unread") with a blue stroke when selected,
/// plus the three-dot options menu (Clear all) on the right side of the row.
class NotificationsFilterChips extends StatelessWidget {
  const NotificationsFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelectFilter,
    this.onClearAll,
  });

  final NotificationsFilter selectedFilter;
  final ValueChanged<NotificationsFilter> onSelectFilter;

  /// Called when "Clear all" is chosen. Hidden when null (nothing to clear).
  final VoidCallback? onClearAll;

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
          isDark: isDark,
          palette: palette,
          strokeColor: strokeColor,
          label: 'All',
          filter: NotificationsFilter.all,
          isSelected: selectedFilter == NotificationsFilter.all,
        ),
        const SizedBox(width: 10),
        _buildChip(
          isDark: isDark,
          palette: palette,
          strokeColor: strokeColor,
          label: 'Unread',
          filter: NotificationsFilter.unread,
          isSelected: selectedFilter == NotificationsFilter.unread,
        ),
        const Spacer(),
        if (onClearAll != null)
          _NotificationOptionsMenu(
            isDark: isDark,
            palette: palette,
            strokeColor: strokeColor,
            onClearAll: onClearAll!,
          ),
      ],
    );
  }

  Widget _buildChip({
    required bool isDark,
    required AppPaletteColors palette,
    required Color strokeColor,
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

class _NotificationOptionsMenu extends StatelessWidget {
  const _NotificationOptionsMenu({
    required this.isDark,
    required this.palette,
    required this.strokeColor,
    required this.onClearAll,
  });

  final bool isDark;
  final AppPaletteColors palette;
  final Color strokeColor;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final dangerColor = isDark
        ? AppColors.darkErrorText
        : const Color(0xFFC0392B);
    final dangerBg = isDark
        ? AppColors.darkErrorBackground
        : AppColors.consentBadgeRedBackground;

    return PopupMenuButton<String>(
      tooltip: 'Notification options',
      offset: const Offset(0, 40),
      elevation: 6,
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? AppColors.darkBorder
              : strokeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      onSelected: (_) => onClearAll(),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'clear_all',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_sweep_rounded,
                  size: 18,
                  color: dangerColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Clear all',
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: dangerColor,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface
              : palette.messagesFilterUnselected,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : strokeColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.more_vert_rounded, size: 20, color: strokeColor),
      ),
    );
  }
}
