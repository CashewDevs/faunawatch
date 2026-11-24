import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/fauna_lens/views/widgets/fauna_lens_theme.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_load_more.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_post_page.dart';

/// A profile-owned route: swipe through the gallery's posts (approved and
/// pending, as filtered) and pop back to the grid.
class GalleryPostViewer extends ConsumerStatefulWidget {
  const GalleryPostViewer({super.key, required this.initialPostId});
  final String initialPostId;

  @override
  ConsumerState<GalleryPostViewer> createState() => _GalleryPostViewerState();
}

class _GalleryPostViewerState extends ConsumerState<GalleryPostViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final items = ref.read(galleryViewModelProvider).items;
    final initial = items.indexWhere((item) => item.id == widget.initialPostId);
    _index = initial < 0 ? 0 : initial;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMoreIfNeeded();
    });
  }

  void _loadMoreIfNeeded() {
    final items = ref.read(galleryViewModelProvider).items;
    if (_index >= items.length - 3) {
      ref.read(galleryViewModelProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryViewModelProvider);
    final items = state.items;
    final colors = FaunaLensTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.header,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        centerTitle: true,
        systemOverlayStyle: colors.statusBar,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.aiResultBackChevron,
            size: 34,
          ),
        ),
        title: Text(
          'My posts',
          style: GoogleFonts.dmSans(
            color: colors.accent,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No posts available.'))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    itemCount: items.length,
                    onPageChanged: (index) {
                      setState(() => _index = index);
                      _loadMoreIfNeeded();
                    },
                    itemBuilder: (_, index) => GalleryPostPage(
                      key: ValueKey(items[index].id),
                      item: items[index],
                    ),
                  ),
                ),
                if (_index >= items.length - 1 && state.hasMore)
                  SafeArea(
                    top: false,
                    child: GalleryLoadMore(
                      isLoading: state.isLoadingMore,
                      onLoad: ref
                          .read(galleryViewModelProvider.notifier)
                          .loadMore,
                    ),
                  ),
              ],
            ),
    );
  }
}
