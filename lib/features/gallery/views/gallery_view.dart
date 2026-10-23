import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';

/// Screen displaying the wildlife sightings photo gallery in a 3-column grid.
///
/// Implements specifications:
/// - Whole background: vertical gradient 0% [#DCF2FF] to 100% [#A4DDFF]
/// - Title: "Gallery" in DM Sans extrabold with yellow underline
/// - Filter button on upper right as a dropdown menu
/// - Photo placeholder cards with yellow [#FFF7D6] details footer
class GalleryView extends ConsumerWidget {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryViewModelProvider);
    final viewModel = ref.read(galleryViewModelProvider.notifier);
    final filteredItems = state.filteredItems;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 1.0],
            colors: [
              AppColors.galleryBackgroundGradientStart,
              AppColors.galleryBackgroundGradientEnd,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gallery Header (Title with underline and Dropdown Filter button)
            GalleryHeader(
              selectedCategory: state.selectedCategory,
              onCategorySelected: viewModel.setCategory,
            ),

            // 3-Column Photo Grid
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return GalleryCard(item: item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
