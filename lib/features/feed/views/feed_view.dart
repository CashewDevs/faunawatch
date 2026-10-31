import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_tab_bar.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';

/// The primary Feed screen with Your Gallery, Map, and For You tabs. For You
/// shows the opened post, or an empty state when no post is open.
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView> {
  // Mapbox is created on first use, then kept alive so switching tabs does not
  // reload the map or lose its camera position.
  bool _mapOpened = false;

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(feedViewModelProvider);
    final tab = ref.watch(feedTabViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;
    if (tab == FeedTab.map) _mapOpened = true;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          FeedTabBar(
            selected: tab,
            onSelect: ref.read(feedTabViewModelProvider.notifier).select,
          ),
          Expanded(
            child: IndexedStack(
              index: tab.index,
              sizing: StackFit.expand,
              children: [
                const GalleryView(),
                if (_mapOpened)
                  const CommunityMapView()
                else
                  const SizedBox.shrink(),
                if (post != null)
                  FeedPostCard(
                    key: ValueKey(post.id),
                    post: post,
                    backgroundColor: backgroundColor,
                  )
                else
                  _EmptyFeed(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Light gray silhouette of binoculars
            BinocularsIcon(
              size: 96,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 20),

            // Title: "No posts yet."
            Text(
              'No posts yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Little descriptive sentence
            Text(
              'Sightings and wildlife reports in your community will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
