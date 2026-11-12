import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_tab_bar.dart';
import 'package:faunawatch/features/feed/views/widgets/for_you_feed.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';

/// The primary Feed screen with Your Gallery, Map, and For You tabs. For You
/// shows the approved reports of the community.
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
                ForYouFeed(backgroundColor: backgroundColor, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
