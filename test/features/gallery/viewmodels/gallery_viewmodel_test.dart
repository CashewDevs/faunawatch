import 'dart:async';

import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../feed/fake_feed_service.dart';
import '../fake_gallery_service.dart';

void main() {
  late FakeGalleryService service;
  late FakeFeedService feed;
  late ProviderContainer container;

  GalleryState state() => container.read(galleryViewModelProvider);
  GalleryViewModel vm() => container.read(galleryViewModelProvider.notifier);

  void create(FakeGalleryService fake) {
    service = fake;
    feed = FakeFeedService(posts: [testPost('community')])
      ..unlisted = fake.posts;
    container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWithValue(service),
        feedServiceProvider.overrideWithValue(feed),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<void> open() async {
    state();
    await pumpEventQueue();
  }

  test('loads own posts independently of the community feed', () async {
    create(
      FakeGalleryService(
        posts: [
          testPost(
            'own',
            authorId: 'me',
            title: 'My sighting',
            photoUrls: [
              'https://photos.invalid/first.webp',
              'https://photos.invalid/second.webp',
            ],
          ),
          testPost(
            'own-second',
            title: 'Another of my sightings',
            authorId: 'me',
            category: ReportCategory.animalInNeed,
            placeName: null,
          ),
        ],
      ),
    );
    expect(state().isLoading, isTrue);
    await pumpEventQueue();
    expect(state().isLoading, isFalse);
    expect(state().items.map((item) => item.id), ['own', 'own-second']);
    expect(state().items.first.title, 'My sighting');
    expect(state().items.first.imageUrl, 'https://photos.invalid/first.webp');
    expect(
      state().items.first.date,
      formatGalleryDate(service.posts.first.createdAt.toLocal()),
    );
    expect(state().items.last.location, 'Approximate location');
    expect(state().items.last.category, ReportCategory.animalInNeed.label);
    expect(state().items.last.imageUrl, isNull);
    expect(feed.pageRequests, isEmpty);
    expect(service.pageRequests, hasLength(1));
  });

  test('preserves the filter across pagination and refresh', () async {
    create(
      FakeGalleryService(
        posts: [
          for (var i = 0; i < 15; i++)
            testPost(
              'p$i',
              index: i,
              category: i.isEven
                  ? ReportCategory.animalInNeed
                  : ReportCategory.otherWildlifeIncident,
            ),
        ],
      ),
    );
    await open();
    vm().setCategory(ReportCategory.animalInNeed.label);
    expect(state().filteredItems, hasLength(6));
    expect(state().hasMore, isTrue);
    await vm().loadMore();
    expect(state().filteredItems, hasLength(8));
    expect(state().hasMore, isFalse);
    expect(service.pageRequests.last!.id, 'p11');
    await vm().refresh();
    expect(state().items, hasLength(12));
    expect(state().selectedCategory, ReportCategory.animalInNeed.label);
    vm().setCategory('All');
    expect(state().filteredItems, hasLength(12));
  });

  test(
    'retries failed initial load and retains cards on failed refresh',
    () async {
      create(
        FakeGalleryService(posts: [testPost('p0')])
          ..pageError = Exception('offline'),
      );
      await open();
      expect(state().hasError, isTrue);
      service.pageError = null;
      await vm().refresh();
      expect(state().hasError, isFalse);
      expect(state().items.single.id, 'p0');
      service.pageError = Exception('offline');
      await vm().refresh();
      expect(state().items.single.id, 'p0');
      expect(state().hasError, isFalse);
    },
  );

  test(
    'gallery loading preserves the Profile destination and feed tab',
    () async {
      create(FakeGalleryService(posts: [testPost('p0'), testPost('p1')]));
      await open();
      container.read(feedTabViewModelProvider.notifier).select(FeedTab.map);
      container
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.profile);
      await vm().refresh();
      expect(container.read(shellViewModelProvider), ShellDestination.profile);
      expect(container.read(feedTabViewModelProvider), FeedTab.map);
      expect(feed.pageRequests, isEmpty);
      expect(service.pageRequests, hasLength(2));
    },
  );

  test('map focus does not reorder Gallery', () async {
    create(
      FakeGalleryService(posts: [testPost('p0')])
        ..unlisted = [testPost('old', index: 100)],
    );
    await open();
    feed.unlisted = [testPost('old', index: 100)];
    await container.read(feedViewModelProvider.notifier).openReport('old');
    expect(state().items.map((item) => item.id), ['p0']);
  });

  test('account changes discard cards and pending responses', () async {
    final gate = Completer<void>();
    final first = FakeGalleryService(posts: [testPost('old-account')])
      ..pageGate = gate;
    final second = FakeGalleryService(posts: [testPost('new-account')]);
    final active = StateProvider<GalleryService>((ref) => first);
    container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith((ref) => ref.watch(active)),
      ],
    );
    addTearDown(container.dispose);
    await open();
    expect(state().isLoading, isTrue);
    container.read(active.notifier).state = second;
    expect(state().items, isEmpty);
    expect(state().isLoading, isTrue);
    await pumpEventQueue();
    expect(state().items.single.id, 'new-account');
    gate.complete();
    await pumpEventQueue();
    expect(state().items.single.id, 'new-account');
    container.read(active.notifier).state = const SignedOutGalleryService();
    expect(state().items, isEmpty);
    await pumpEventQueue();
    expect(state().items, isEmpty);
    expect(state().hasError, isFalse);
  });

  test('formats compact calendar dates', () {
    expect(formatGalleryDate(DateTime(2026, 1, 1)), 'Jan 1');
    expect(formatGalleryDate(DateTime(2026, 12, 31)), 'Dec 31');
  });

  test('refresh supersedes a pending older page', () async {
    create(
      FakeGalleryService(
        posts: [for (var i = 0; i < 25; i++) testPost('p$i', index: i)],
      ),
    );
    await open();
    final gate = Completer<void>();
    service.pageGate = gate;
    final older = vm().loadMore();
    await vm().loadMore();
    expect(service.pageRequests, hasLength(2));
    service.pageGate = null;
    service.posts = [testPost('new'), ...service.posts];
    await vm().refresh();
    gate.complete();
    await older;
    expect(state().items, hasLength(GalleryService.pageSize));
    expect(state().items.first.id, 'new');
    expect(state().isLoadingMore, isFalse);
  });

  test('failed pagination preserves cards and can retry', () async {
    create(
      FakeGalleryService(
        posts: [for (var i = 0; i < 15; i++) testPost('p$i', index: i)],
      ),
    );
    await open();
    service.pageError = Exception('offline');
    await vm().loadMore();
    expect(state().items, hasLength(12));
    expect(state().hasMore, isTrue);
    expect(state().message, 'Could not load older posts.');
    vm().clearMessage();
    expect(state().message, isNull);
    service.pageError = null;
    await vm().loadMore();
    expect(state().items, hasLength(15));
    expect(state().hasMore, isFalse);
  });
}
