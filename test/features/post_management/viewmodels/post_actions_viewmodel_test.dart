import 'dart:async';

import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/post_management/services/post_management_service.dart';
import 'package:faunawatch/features/post_management/viewmodels/post_actions_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../feed/fake_feed_service.dart';
import '../../gallery/fake_gallery_service.dart';
import '../fake_post_management_service.dart';

void main() {
  late FakePostManagementService service;
  late FakeFeedService feed;
  late FakeGalleryService gallery;
  late ProviderContainer container;

  PostActionsViewModel vm() =>
      container.read(postActionsViewModelProvider.notifier);
  List<String> feedIds() =>
      container.read(feedViewModelProvider).posts.map((p) => p.id).toList();
  List<String> galleryIds() =>
      container.read(galleryViewModelProvider).items.map((i) => i.id).toList();

  setUp(() {
    service = FakePostManagementService();
    feed = FakeFeedService(
      posts: [testPost('a', index: 0), testPost('b', index: 1)],
    );
    gallery = FakeGalleryService(
      posts: [testPost('a', index: 0), testPost('b', index: 1)],
    );
    container = ProviderContainer(
      overrides: [
        postManagementServiceProvider.overrideWithValue(service),
        feedServiceProvider.overrideWithValue(feed),
        galleryServiceProvider.overrideWithValue(gallery),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> openFeedAndGallery() async {
    container.read(feedViewModelProvider);
    container.read(galleryViewModelProvider);
    await pumpEventQueue();
  }

  test(
    'hiding takes the post out of the feed and badges it in the gallery',
    () async {
      await openFeedAndGallery();
      final result = await vm().setHidden('a', hidden: true);
      expect(result, (done: true, error: null));
      expect(service.hiddenCalls, [('a', true)]);
      expect(feedIds(), ['b']);
      expect(galleryIds(), ['a', 'b']);
      expect(
        container.read(galleryViewModelProvider).items.first.isHidden,
        isTrue,
      );
    },
  );

  test('showing again reloads the feed so the post comes back', () async {
    await openFeedAndGallery();
    await vm().setHidden('a', hidden: true);
    final pagesBefore = feed.pageRequests.length;
    await vm().setHidden('a', hidden: false);
    await pumpEventQueue();
    expect(feed.pageRequests.length, pagesBefore + 1);
    expect(feedIds(), ['a', 'b']);
    expect(
      container.read(galleryViewModelProvider).items.first.isHidden,
      isFalse,
    );
  });

  test('deleting removes the post from the feed and the gallery', () async {
    await openFeedAndGallery();
    final result = await vm().delete('a');
    expect(result.done, isTrue);
    expect(service.deleted, ['a']);
    expect(feedIds(), ['b']);
    expect(galleryIds(), ['b']);
  });

  test('screens that were never opened are not started', () async {
    await vm().delete('a');
    expect(container.exists(feedViewModelProvider), isFalse);
    expect(container.exists(galleryViewModelProvider), isFalse);
    expect(container.exists(communityMapViewModelProvider), isFalse);
  });

  test('a failure leaves everything as it was and explains why', () async {
    await openFeedAndGallery();
    service.error = const PostActionException(PostActionFailure.notPublic);
    final result = await vm().setHidden('a', hidden: true);
    expect(result.done, isFalse);
    expect(result.error, PostActionFailure.notPublic.message);
    expect(feedIds(), ['a', 'b']);

    service.error = Exception('offline');
    final other = await vm().delete('a');
    expect(other.error, PostActionFailure.unknown.message);
    expect(galleryIds(), ['a', 'b']);
  });

  test('a second tap while the post is busy is ignored', () async {
    final gate = Completer<void>();
    service.gate = gate;
    final first = vm().delete('a');
    expect(container.read(postActionsViewModelProvider), {'a'});
    final second = await vm().setHidden('a', hidden: true);
    expect(second, (done: false, error: null));
    gate.complete();
    expect((await first).done, isTrue);
    expect(container.read(postActionsViewModelProvider), isEmpty);
    expect(service.hiddenCalls, isEmpty);
  });
}
