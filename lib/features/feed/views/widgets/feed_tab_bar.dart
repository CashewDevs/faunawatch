import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';

/// Text tabs at the top of the feed, with an underline on the selected one.
class FeedTabBar extends StatelessWidget {
  const FeedTabBar({super.key, required this.selected, required this.onSelect});

  final FeedTab selected;
  final ValueChanged<FeedTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTab(context, FeedTab.gallery, 'Your Gallery'),
          _buildTab(context, FeedTab.map, 'Map'),
          _buildTab(context, FeedTab.forYou, 'For You'),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, FeedTab tab, String label) {
    final theme = Theme.of(context);
    final isSelected = tab == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onSelect(tab),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.messagesHeaderUnderline
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
