import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/screens/gallery_post_viewer.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_header.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_load_more.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_notice.dart';

/// The profile's own-post gallery, sharing one scroll view with its header.
class GalleryView extends ConsumerWidget {
  const GalleryView({super.key, this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryViewModelProvider);
    final viewModel = ref.read(galleryViewModelProvider.notifier);
    final items = state.filteredItems;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    ref.listen(galleryViewModelProvider.select((state) => state.message), (
      _,
      message,
    ) {
      if (message == null) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 8),
          ),
        );
      viewModel.clearMessage();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final movingToOlder =
                (notification is ScrollUpdateNotification &&
                    (notification.scrollDelta ?? 0) > 0) ||
                (notification is OverscrollNotification &&
                    notification.overscroll > 0);
            if (movingToOlder && notification.metrics.extentAfter < 300) {
              viewModel.loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (header != null) SliverToBoxAdapter(child: header),
              SliverToBoxAdapter(
                child: GalleryHeader(
                  selectedCategory: state.selectedCategory,
                  onCategorySelected: viewModel.setCategory,
                ),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 20),
                    child: GalleryNotice(
                      state: state,
                      onRetry: viewModel.refresh,
                      onLoadMore: viewModel.loadMore,
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => GalleryCard(
                      key: ValueKey(items[index].id),
                      item: items[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              GalleryPostViewer(initialPostId: items[index].id),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset + 20),
                    child: state.hasMore
                        ? GalleryLoadMore(
                            isLoading: state.isLoadingMore,
                            onLoad: viewModel.loadMore,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
