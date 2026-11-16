import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';

import '../feed/fake_feed_service.dart';

class FakeGalleryService extends FakeFeedService implements GalleryService {
  FakeGalleryService({super.posts});

  @override
  Future<List<FeedPost>> fetchPage({FeedPost? before}) async {
    pageRequests.add(before);
    await pageGate?.future;
    if (pageError != null) throw pageError!;
    final start = before == null
        ? 0
        : posts.indexWhere((post) => post.id == before.id) + 1;
    return posts.skip(start).take(GalleryService.pageSize).toList();
  }
}
