import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';

/// The Your Gallery tab: wildlife sighting photos in a 3-column grid with a
/// category filter. Shows through the feed's theme-colored background.
///
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
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropdown Filter button
          GalleryHeader(
            selectedCategory: state.selectedCategory,
            onCategorySelected: viewModel.setCategory,
          ),

          // 3-Column Photo Grid
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    // The shell reports the floating nav bar's height here.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      MediaQuery.paddingOf(context).bottom + 20,
                    ),
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
    );
  }
}
