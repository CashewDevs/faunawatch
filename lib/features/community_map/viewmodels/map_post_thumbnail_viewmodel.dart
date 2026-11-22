import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The approved post behind a map pin, loaded through the For You feed.
///
/// The map's own data has no author, so the pin's card and the list of posts
/// sharing a pin read the poster's name, picture and photos from here. Signed
/// URLs are discarded once nothing shows the post, and it reloads on account
/// changes.
final mapPostProvider = FutureProvider.autoDispose.family<FeedPost?, String>(
  (ref, postId) => ref.watch(feedServiceProvider).fetchPost(postId),
);

/// Loads a pin preview's first available photo through the approved-post service.
class MapPostThumbnailViewModel
    extends AutoDisposeFamilyAsyncNotifier<String?, String> {
  @override
  Future<String?> build(String postId) async {
    final post = await ref.watch(mapPostProvider(postId).future);
    return post?.photoUrls.firstOrNull;
  }

  /// Loads the post again, which also refreshes its author.
  void retry() => ref.invalidate(mapPostProvider(arg));
}

/// Discard signed URLs when the dialog closes and reload on account changes.
final mapPostThumbnailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<MapPostThumbnailViewModel, String?, String>(
      MapPostThumbnailViewModel.new,
    );
