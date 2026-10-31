import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// Single photo card in the gallery grid.
///
/// Features:
/// - Rounded rectangular card (BorderRadius.circular(18))
/// - Blue gradient photo display / placeholder area
/// - Yellow [#FFF7D6] bottom section for photo details placeholder
class GalleryCard extends StatelessWidget {
  const GalleryCard({super.key, required this.item, this.onTap});

  final GalleryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}, ${item.location}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.galleryBackgroundGradientStart,
                AppColors.galleryBackgroundGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top area: image or photo placeholder
              Expanded(
                child: item.imageAsset != null
                    ? Image.asset(
                        item.imageAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.expand(),
                      )
                    : const SizedBox.expand(),
              ),

              // Bottom details container: #FFF7D6
              Container(
                height: 32,
                color: AppColors.galleryCardDetailsYellow,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B5800),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.date.isNotEmpty)
                      Text(
                        item.date,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8A7300),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
