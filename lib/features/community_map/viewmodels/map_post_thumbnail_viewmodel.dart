import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads a pin preview's first available photo through the approved-post service.
class MapPostThumbnailViewModel
    extends AutoDisposeFamilyAsyncNotifier<String?, String> {
  @override
  Future<String?> build(String postId) async {
    final post = await ref.watch(feedServiceProvider).fetchPost(postId);
    return post?.photoUrls.firstOrNull;
  }

  void retry() => ref.invalidateSelf();
}

/// Discard signed URLs when the dialog closes and reload on account changes.
final mapPostThumbnailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<MapPostThumbnailViewModel, String?, String>(
      MapPostThumbnailViewModel.new,
    );
