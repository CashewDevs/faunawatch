import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';

/// The gallery's three-column layout, shared with its loading skeleton.
const galleryGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: 12,
  mainAxisSpacing: 14,
  childAspectRatio: 0.68,
);

/// Single photo card in the gallery grid.
///
/// Features:
/// - Rounded rectangular card (BorderRadius.circular(18))
/// - Signed network photo over a blue gradient fallback
/// - Yellow [#FFF7D6] bottom section for the title and submission date
/// - A "Pending review" badge on posts an admin has not reviewed yet, shown
///   under every filter so pending posts never look published
class GalleryCard extends StatelessWidget {
  const GalleryCard({super.key, required this.item, this.onTap});

  final GalleryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [
        item.title,
        item.location,
        if (item.isPending) PendingReviewBadge.label,
      ].join(', '),
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const _PhotoPlaceholder(),
                            errorBuilder: (_, _, _) =>
                                const _PhotoPlaceholder(),
                          )
                        : const _PhotoPlaceholder(),
                    if (item.isPending)
                      const Positioned(
                        top: 6,
                        left: 6,
                        right: 6,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: PendingReviewBadge(),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom details container: #FFF7D6
              Container(
                height: 32,
                color: AppPaletteColors.of(context).galleryCardDetailsYellow,
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
                          color: AppPaletteColors.of(context).resolve(
                            const Color(0xFF6B5800),
                            Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
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
                          color: AppPaletteColors.of(context).resolve(
                            const Color(0xFF8A7300),
                            Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
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

/// Marks a post that is still waiting for an admin's review: small on grid
/// tiles, [large] on the full-screen post.
class PendingReviewBadge extends StatelessWidget {
  const PendingReviewBadge({super.key, this.large = false});

  static const label = 'Pending review';
  final bool large;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // Scales down instead of overflowing on narrow tiles.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: large
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(large ? 14 : 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: large ? 16 : 11,
                color: const Color(0xFFFFC94D),
              ),
              SizedBox(width: large ? 5 : 3),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: large ? 13 : 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.image_outlined, color: Colors.white70, size: 28),
  );
}
