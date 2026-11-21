import 'package:faunawatch/features/gallery/views/widgets/gallery_load_more.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_post_page.dart';
import 'package:faunawatch/features/public_profile/viewmodels/public_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Browses only this public gallery and returns to its original grid position.
class PublicGalleryPostViewer extends ConsumerStatefulWidget {
  const PublicGalleryPostViewer({
    super.key,
    required this.userId,
    required this.initialPostId,
  });
  final String userId, initialPostId;

  @override
  ConsumerState<PublicGalleryPostViewer> createState() =>
      _PublicGalleryPostViewerState();
}

class _PublicGalleryPostViewerState
    extends ConsumerState<PublicGalleryPostViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final posts = ref.read(publicProfileViewModelProvider(widget.userId)).posts;
    final initial = posts.indexWhere((post) => post.id == widget.initialPostId);
    _index = initial < 0 ? 0 : initial;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
  }

  void _loadMore() {
    final provider = publicProfileViewModelProvider(widget.userId);
    if (_index >= ref.read(provider).posts.length - 3) {
      ref.read(provider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = publicProfileViewModelProvider(widget.userId);
    final state = ref.watch(provider);
    final items = ref.read(provider.notifier).items;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Public Gallery',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
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
                      _loadMore();
                    },
                    itemBuilder: (_, index) => GalleryPostPage(
                      key: ValueKey(items[index].id),
                      item: items[index],
                      authorId: widget.userId,
                      onAuthorTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                if (_index >= items.length - 1 && state.hasMore)
                  SafeArea(
                    top: false,
                    child: GalleryLoadMore(
                      isLoading: state.isLoadingMore,
                      onLoad: ref.read(provider.notifier).loadMore,
                    ),
                  ),
              ],
            ),
    );
  }
}
