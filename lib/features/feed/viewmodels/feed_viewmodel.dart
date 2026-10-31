import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

class FeedViewModel extends Notifier<FeedPost?> {
  @override
  FeedPost? build() => null;

  /// Shows the sample post in the For You tab.
  void openSamplePost(String postId) {
    if (postId != sampleMapPost.id) return;
    state = sampleMapPost;
    ref.read(feedTabViewModelProvider.notifier).select(FeedTab.forYou);
  }
}

final feedViewModelProvider = NotifierProvider<FeedViewModel, FeedPost?>(
  FeedViewModel.new,
);

enum FeedTab { gallery, map, forYou }

/// Holds the tab selected at the top of the feed.
class FeedTabViewModel extends Notifier<FeedTab> {
  @override
  FeedTab build() => FeedTab.forYou;

  void select(FeedTab tab) => state = tab;
}

final feedTabViewModelProvider = NotifierProvider<FeedTabViewModel, FeedTab>(
  FeedTabViewModel.new,
);
