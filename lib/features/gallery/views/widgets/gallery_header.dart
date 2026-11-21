import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/gallery/models/gallery_filter.dart';

/// My Gallery section title, the category Filter menu and the status chips.
class GalleryHeader extends StatelessWidget {
  const GalleryHeader({
    super.key,
    required this.filter,
    this.onStatusSelected,
    required this.onCategorySelected,
    this.title = 'My Gallery',
  });

  final GalleryFilter filter;
  final ValueChanged<GalleryStatusFilter>? onStatusSelected;
  final String title;

  /// Called with `null` for "All".
  final ValueChanged<ReportCategory?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppPaletteColors.of(context);
    final category = filter.category;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<_CategoryOption>(
                    tooltip: 'Filter by category',
                    onSelected: (option) => onCategorySelected(option.category),
                    offset: const Offset(0, 36),
                    elevation: 4,
                    color: colors.galleryFilterButtonBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.galleryFilterButtonBorder,
                        width: 1.5,
                      ),
                    ),
                    itemBuilder: (context) => [
                      _buildMenuItem(
                        context,
                        const _CategoryOption(null),
                        'All',
                        category == null,
                      ),
                      for (final option in ReportCategory.values)
                        _buildMenuItem(
                          context,
                          _CategoryOption(option),
                          option.label,
                          category == option,
                        ),
                    ],
                    child: _FilterButton(
                      label: category == null
                          ? 'Filter'
                          : 'Filter · ${category.label}',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onStatusSelected != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final status in GalleryStatusFilter.values)
                  _StatusChip(
                    label: status.label,
                    selected: filter.status == status,
                    onTap: () => onStatusSelected!(status),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<_CategoryOption> _buildMenuItem(
    BuildContext context,
    _CategoryOption value,
    String label,
    bool isSelected,
  ) {
    final color = AppPaletteColors.of(context).galleryTitleBlue;
    return PopupMenuItem<_CategoryOption>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          if (isSelected) Icon(Icons.check_rounded, size: 18, color: color),
        ],
      ),
    );
  }
}

/// A menu value that can also mean "All" (a `null` menu value would count as
/// closing the menu without a choice).
class _CategoryOption {
  const _CategoryOption(this.category);
  final ReportCategory? category;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppPaletteColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.galleryFilterButtonBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.galleryFilterButtonBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_rounded, size: 16, color: colors.galleryTitleBlue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.galleryTitleBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPaletteColors.of(context);
    final accent = colors.galleryTitleBlue;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? accent : colors.galleryFilterButtonBackground,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? accent : colors.galleryFilterButtonBorder,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? ThemeData.estimateBrightnessForColor(accent) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black
                    : accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
