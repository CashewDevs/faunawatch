import 'dart:async';

import 'package:faunawatch/features/feed/models/feed_state.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_feed_service.dart';

void main() {
  late FakeFeedService service;
  late ProviderContainer container;

  FeedState state() => container.read(feedViewModelProvider);
  FeedViewModel vm() => container.read(feedViewModelProvider.notifier);
  List<String> ids() => state().posts.map((post) => post.id).toList();

  /// Creates the ViewModel and lets the first page arrive.
  Future<void> open() async {
    container.read(feedViewModelProvider);
    await pumpEventQueue();
  }

  List<String> idsUpTo(int count) => [for (var i = 0; i < count; i++) 'p$i'];

  FakeFeedService serviceWith(int count) => FakeFeedService(
    posts: [
      for (var i = 0; i < count; i++)
        testPost('p$i', index: i, likeCount: 5, commentCount: 1),
    ],
  );

  void create(FakeFeedService fake) {
    service = fake;
    container = ProviderContainer(
      overrides: [feedServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  }

  group('loading', () {
    test('starts loading, then shows the first page newest first', () async {
      create(serviceWith(3));
      expect(state().isLoading, isTrue);
      expect(state().posts, isEmpty);
      await pumpEventQueue();
      expect(state().isLoading, isFalse);
      expect(ids(), ['p0', 'p1', 'p2']);
      expect(state().hasMore, isFalse);
      expect(state().hasError, isFalse);
      expect(service.pageRequests, [null]);
    });

    test('an empty feed is not an error', () async {
      create(serviceWith(0));
      await open();
      expect(state().posts, isEmpty);
      expect(state().isLoading, isFalse);
      expect(state().hasError, isFalse);
    });

    test('a failed first load is an error with nothing to show', () async {
      create(serviceWith(2)..pageError = Exception('offline'));
      await open();
      expect(state().hasError, isTrue);
      expect(state().isLoading, isFalse);
      expect(state().posts, isEmpty);

      service.pageError = null;
      await vm().refresh();
      expect(state().hasError, isFalse);
      expect(ids(), ['p0', 'p1']);
    });
  });

  group('paging', () {
    test('a full page means there may be more, and loadMore appends', () async {
      create(serviceWith(25));
      await open();
      expect(ids(), idsUpTo(FeedService.pageSize));
      expect(state().hasMore, isTrue);

      await vm().loadMore();
      expect(ids(), idsUpTo(2 * FeedService.pageSize));
      // The cursor is the last post of the previous page.
      expect(service.pageRequests.last!.id, 'p9');
      expect(state().hasMore, isTrue);

      await vm().loadMore();
      expect(ids(), idsUpTo(25));
      expect(state().hasMore, isFalse);

      await vm().loadMore();
      expect(service.pageRequests, hasLength(3));
    });

    test('does not load while a page is already loading', () async {
      create(serviceWith(25));
      await open();
      service.pageGate = Completer<void>();
      final first = vm().loadMore();
      expect(state().isLoadingMore, isTrue);
      await vm().loadMore();
      expect(service.pageRequests, hasLength(2));
      service.pageGate!.complete();
      await first;
      expect(state().isLoadingMore, isFalse);
      expect(state().posts, hasLength(20));
    });

    test('drops posts that are already shown', () async {
      create(serviceWith(25));
      await open();
      // A shown post comes back on the next page, e.g. after a re-approval.
      service.posts = [
        ...service.posts.take(10),
        testPost('p5', index: 5),
        ...service.posts.skip(10),
      ];
      await vm().loadMore();
      expect(ids().toSet(), hasLength(ids().length));
      expect(state().posts, hasLength(19));
    });

    test('a failed page keeps the posts, says so, and can retry', () async {
      create(serviceWith(25));
      await open();
      service.pageError = Exception('offline');
      await vm().loadMore();
      expect(state().posts, hasLength(10));
      expect(state().isLoadingMore, isFalse);
      expect(state().hasMore, isTrue);
      expect(state().message, 'Could not load more posts.');

      vm().clearMessage();
      expect(state().message, isNull);
      service.pageError = null;
      await vm().loadMore();
      expect(state().posts, hasLength(20));
    });
  });

  group('refresh', () {
    test('replaces the posts with the newest page', () async {
      create(serviceWith(25));
      await open();
      await vm().loadMore();
      service.posts = [testPost('new', title: 'New'), ...service.posts];

      await vm().refresh();
      expect(state().isRefreshing, isFalse);
      expect(ids().first, 'new');
      expect(state().posts, hasLength(FeedService.pageSize));
      expect(state().hasMore, isTrue);
    });

    test('a failed refresh keeps the old posts', () async {
      create(serviceWith(3));
      await open();
      service.pageError = Exception('offline');
      await vm().refresh();
      expect(ids(), ['p0', 'p1', 'p2']);
      expect(state().hasError, isFalse);
      expect(state().isRefreshing, isFalse);
      expect(state().message, 'Could not refresh the feed.');
    });

    test('refreshing twice at once sends one request', () async {
      create(serviceWith(3));
      await open();
      service.pageGate = Completer<void>();
      final first = vm().refresh();
      expect(state().isRefreshing, isTrue);
      await vm().refresh();
      expect(service.pageRequests, hasLength(2));
      service.pageGate!.complete();
      await first;
    });
  });

  group('likes', () {
    test('liking is optimistic and saved', () async {
      create(serviceWith(2));
      await open();
      service.likeGate = Completer<void>();
      final saving = vm().toggleLike('p0');
      expect(state().posts.first.likedByMe, isTrue);
      expect(state().posts.first.likeCount, 6);
      service.likeGate!.complete();
      await saving;
      expect(service.likes, ['p0']);
      expect(state().posts.first.likedByMe, isTrue);
      expect(state().posts.first.likeCount, 6);
      expect(state().posts.last.likeCount, 5);
    });

    test('unliking removes the like', () async {
      create(
        FakeFeedService(posts: [testPost('p0', likeCount: 3, likedByMe: true)]),
      );
      await open();
      await vm().toggleLike('p0');
      expect(service.unlikes, ['p0']);
      expect(state().posts.single.likedByMe, isFalse);
      expect(state().posts.single.likeCount, 2);
    });

    test('a failed like is rolled back with a message', () async {
      create(serviceWith(1)..likeError = Exception('denied'));
      await open();
      service.likeGate = Completer<void>();
      final saving = vm().toggleLike('p0');
      expect(state().posts.single.likedByMe, isTrue);
      service.likeGate!.complete();
      await saving;
      expect(state().posts.single.likedByMe, isFalse);
      expect(state().posts.single.likeCount, 5);
      expect(state().message, 'Could not update your like.');
    });

    test('a failed unlike is rolled back', () async {
      create(
        FakeFeedService(posts: [testPost('p0', likeCount: 3, likedByMe: true)])
          ..likeError = Exception('denied'),
      );
      await open();
      await vm().toggleLike('p0');
      expect(state().posts.single.likedByMe, isTrue);
      expect(state().posts.single.likeCount, 3);
    });

    test(
      'taps while saving are ignored, then it can be toggled again',
      () async {
        create(serviceWith(1));
        await open();
        service.likeGate = Completer<void>();
        final saving = vm().toggleLike('p0');
        await vm().toggleLike('p0');
        expect(service.likes, ['p0']);
        expect(service.unlikes, isEmpty);
        expect(state().posts.single.likedByMe, isTrue);
        service.likeGate!.complete();
        await saving;

        await vm().toggleLike('p0');
        expect(service.unlikes, ['p0']);
        expect(state().posts.single.likedByMe, isFalse);
        expect(state().posts.single.likeCount, 5);
      },
    );

    test('an unknown post does nothing', () async {
      create(serviceWith(1));
      await open();
      await vm().toggleLike('nope');
      expect(service.likes, isEmpty);
    });
  });

  group('comment counts', () {
    test('adjust and set the count of one post', () async {
      create(serviceWith(2));
      await open();
      vm().adjustCommentCount('p0', 1);
      expect(state().posts.first.commentCount, 2);
      vm().setCommentCount('p1', 7);
      expect(state().posts.last.commentCount, 7);
      vm().adjustCommentCount('p0', -5);
      expect(state().posts.first.commentCount, 0);
    });
  });

  group('openReport (map to feed)', () {
    test('selects For You and focuses a loaded post', () async {
      create(serviceWith(3));
      container.read(feedTabViewModelProvider.notifier).select(FeedTab.gallery);
      await open();
      await vm().openReport('p2');
      expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
      expect(state().focusedPostId, 'p2');
      expect(state().pinnedPost, isNull);
      vm().consumeFocus();
      expect(state().focusedPostId, isNull);
    });

    test('fetches a post that is not loaded and shows it first', () async {
      create(
        FakeFeedService(posts: serviceWith(3).posts)
          ..unlisted = [testPost('old', index: 50, title: 'Old find')],
      );
      await open();
      await vm().openReport('old');
      expect(state().focusedPostId, 'old');
      expect(state().pinnedPost?.id, 'old');
      expect(state().visiblePosts.map((post) => post.id), [
        'old',
        'p0',
        'p1',
        'p2',
      ]);

      // Likes reach the pinned post too.
      await vm().toggleLike('old');
      expect(state().pinnedPost!.likedByMe, isTrue);

      // A refresh loads the pages again and drops the pin.
      await vm().refresh();
      expect(state().pinnedPost, isNull);
      expect(ids(), ['p0', 'p1', 'p2']);
    });

    test('says so when the post is gone', () async {
      create(serviceWith(1));
      await open();
      await vm().openReport('gone');
      expect(state().message, 'That post is no longer available.');
      expect(state().focusedPostId, isNull);
    });
  });

  test('a new service (account change) starts over', () async {
    final first = serviceWith(2);
    final second = FakeFeedService(posts: [testPost('other')]);
    final active = StateProvider<FeedService>((ref) => first);
    container = ProviderContainer(
      overrides: [feedServiceProvider.overrideWith((ref) => ref.watch(active))],
    );
    addTearDown(container.dispose);
    service = first;
    await open();
    expect(ids(), ['p0', 'p1']);

    container.read(active.notifier).state = second;
    expect(state().posts, isEmpty);
    expect(state().isLoading, isTrue);
    await pumpEventQueue();
    expect(ids(), ['other']);
  });
}
