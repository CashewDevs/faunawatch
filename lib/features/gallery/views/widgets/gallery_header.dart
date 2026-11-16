import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';

/// My Gallery section title and the report category filter.
class GalleryHeader extends StatelessWidget {
  const GalleryHeader({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Gallery',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onCategorySelected,
            offset: const Offset(0, 36),
            elevation: 4,
            color: AppPaletteColors.of(context).galleryFilterButtonBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppPaletteColors.of(context).galleryFilterButtonBorder,
                width: 1.5,
              ),
            ),
            itemBuilder: (context) => [
              _buildMenuItem(context, 'All', selectedCategory == 'All'),
              for (final category in ReportCategory.values)
                _buildMenuItem(
                  context,
                  category.label,
                  selectedCategory == category.label,
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppPaletteColors.of(
                  context,
                ).galleryFilterButtonBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppPaletteColors.of(context).galleryFilterButtonBorder,
                  width: 1.5,
                ),
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
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: AppPaletteColors.of(context).galleryTitleBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPaletteColors.of(context).galleryTitleBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String label,
    bool isSelected,
  ) {
    return PopupMenuItem<String>(
      value: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppPaletteColors.of(context).galleryTitleBlue,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: AppPaletteColors.of(context).galleryTitleBlue,
            ),
        ],
      ),
    );
  }
}
