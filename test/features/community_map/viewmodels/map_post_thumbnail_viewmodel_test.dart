import 'dart:async';

import 'package:faunawatch/features/community_map/viewmodels/map_post_thumbnail_viewmodel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../feed/fake_feed_service.dart';

void main() {
  late _Feed service;
  late ProviderContainer container;

  setUp(() {
    service = _Feed();
    container = ProviderContainer(
      overrides: [feedServiceProvider.overrideWithValue(service)],
    );
  });
  tearDown(() => container.dispose());

  test(
    'loads the selected report and uses its first signed photo URL',
    () async {
      service.posts = [
        testPost('r1', photoUrls: ['https://photos.invalid/first', 'second']),
        testPost('r2', photoUrls: ['https://photos.invalid/other']),
      ];
      final provider = mapPostThumbnailViewModelProvider('r1');
      container.listen(provider, (_, _) {});
      expect(
        await container.read(provider.future),
        'https://photos.invalid/first',
      );
      expect(service.requests, ['r1']);
    },
  );

  test(
    'a post without photos or no longer approved has no thumbnail',
    () async {
      service.posts = [testPost('no-photo')];
      for (final id in ['no-photo', 'removed']) {
        final provider = mapPostThumbnailViewModelProvider(id);
        container.listen(provider, (_, _) {});
        expect(await container.read(provider.future), isNull);
      }
    },
  );

  test(
    'failed requests expose an error and retry fetches fresh URLs',
    () async {
      service.fail = true;
      final provider = mapPostThumbnailViewModelProvider('r1');
      container.listen(provider, (_, _) {});
      await expectLater(container.read(provider.future), throwsStateError);
      expect(container.read(provider).hasError, isTrue);
      service.fail = false;
      service.posts = [
        testPost('r1', photoUrls: ['fresh-url']),
      ];
      container.read(provider.notifier).retry();
      expect(await container.read(provider.future), 'fresh-url');
      expect(service.requests, ['r1', 'r1']);
    },
  );

  test(
    'reopening a preview signs again instead of keeping an expired URL',
    () async {
      service.posts = [
        testPost('r1', photoUrls: ['old-url']),
      ];
      final provider = mapPostThumbnailViewModelProvider('r1');
      final subscription = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), 'old-url');
      subscription.close();
      await pumpEventQueue();
      service.posts = [
        testPost('r1', photoUrls: ['new-url']),
      ];
      container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), 'new-url');
      expect(service.requests, ['r1', 'r1']);
    },
  );

  test('photo responses for different pins remain separate', () async {
    final pending = Completer<FeedPost?>();
    service.pending['r1'] = pending;
    service.posts = [
      testPost('r2', photoUrls: ['second-url']),
    ];
    final first = mapPostThumbnailViewModelProvider('r1');
    final second = mapPostThumbnailViewModelProvider('r2');
    container.listen(first, (_, _) {});
    container.listen(second, (_, _) {});
    expect(await container.read(second.future), 'second-url');
    pending.complete(testPost('r1', photoUrls: ['first-url']));
    expect(await container.read(first.future), 'first-url');
    expect(container.read(second).valueOrNull, 'second-url');
  });

  test('service replacement drops an old account photo request', () async {
    final oldRequest = Completer<FeedPost?>();
    service.pending['r1'] = oldRequest;
    final activeService = StateProvider<FeedService>((ref) => service);
    final sessionContainer = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWith((ref) => ref.watch(activeService)),
      ],
    );
    addTearDown(sessionContainer.dispose);
    final provider = mapPostThumbnailViewModelProvider('r1');
    sessionContainer.listen(provider, (_, _) {});
    expect(sessionContainer.read(provider).isLoading, isTrue);
    sessionContainer.read(activeService.notifier).state =
        const SignedOutFeedService();
    expect(await sessionContainer.read(provider.future), isNull);
    oldRequest.complete(testPost('r1', photoUrls: ['old-account-url']));
    await pumpEventQueue();
    expect(sessionContainer.read(provider).valueOrNull, isNull);
  });
}

class _Feed extends FakeFeedService {
  final requests = <String>[];
  final pending = <String, Completer<FeedPost?>>{};
  bool fail = false;

  @override
  Future<FeedPost?> fetchPost(String postId) async {
    requests.add(postId);
    if (fail) throw StateError('offline');
    return pending[postId]?.future ?? super.fetchPost(postId);
  }
}
