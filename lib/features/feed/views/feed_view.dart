import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/app_update/views/widgets/app_update_banner.dart';
import 'package:faunawatch/features/feed/views/widgets/for_you_feed.dart';

/// The primary Feed screen: the approved reports of the community (For You).
/// The community map is its own bottom-bar tab. A banner at the top offers a
/// newer app version when there is one (Android).
class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          const AppUpdateBanner(),
          Expanded(
            child: ForYouFeed(backgroundColor: backgroundColor, isDark: isDark),
          ),
        ],
      ),
    );
  }
}
