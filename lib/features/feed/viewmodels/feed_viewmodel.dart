import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';

class FeedViewModel extends Notifier<FeedPost?> {
  @override
  FeedPost? build() => null;

  void openSamplePost(String postId) {
    if (postId == sampleMapPost.id) state = sampleMapPost;
  }
}

final feedViewModelProvider = NotifierProvider<FeedViewModel, FeedPost?>(
  FeedViewModel.new,
);
