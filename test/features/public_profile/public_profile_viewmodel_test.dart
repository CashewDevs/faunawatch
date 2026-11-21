import 'dart:async';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_draft.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:faunawatch/features/public_profile/viewmodels/public_profile_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_public_profile_service.dart';

void main() {
  late ProviderContainer container;
  late FakePublicProfileService service;
  late StreamController<String?> users;
  final provider = publicProfileViewModelProvider('other');

  Future<void> open({String? viewer = 'me'}) async {
    users = StreamController<String?>();
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => users.stream),
        publicProfileServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await users.close();
    });
    container.listen(provider, (_, _) {});
    users.add(viewer);
    await pumpEventQueue();
  }

  PublicProfileViewModel vm() => container.read(provider.notifier);
  setUp(() => service = FakePublicProfileService());

  test(
    'loads selected identity and discards posts from other authors',
    () async {
      service.posts = [
        publicPost('a'),
        publicPost('foreign', authorId: 'else'),
      ];
      await open();
      expect(service.profileRequests, ['other']);
      expect(service.postRequests.single.userId, 'other');
      expect(container.read(provider).profile!.username, 'Forest Ranger');
      expect(container.read(provider).posts.map((post) => post.id), ['a']);
      expect(vm().items.single.isPending, isFalse);
      expect(vm().items.single.date, 'Nov 20');
    },
  );

  test(
    'paginates by submission cursor and ignores overlapping posts',
    () async {
      final first = List.generate(12, (i) => publicPost('p$i'));
      service.posts = first;
      await open();
      expect(container.read(provider).hasMore, isTrue);
      service.posts = [first.last, publicPost('older', day: 19)];
      await vm().loadMore();
      expect(service.postRequests.last.before, same(first.last));
      expect(container.read(provider).posts, hasLength(13));
      expect(container.read(provider).hasMore, isFalse);
    },
  );

  test(
    'category changes discard superseded pages and reset the cursor',
    () async {
      final oldPage = Completer<List<FeedPost>>();
      service.onPosts = (_, _, category) async {
        if (category == null) return oldPage.future;
        return [publicPost('invasive', category: category)];
      };
      await open();
      expect(container.read(provider).isLoadingPosts, isTrue);
      await vm().setCategory(ReportCategory.possibleInvasiveSpecies);
      oldPage.complete([publicPost('old')]);
      await pumpEventQueue();
      expect(container.read(provider).posts.single.id, 'invasive');
      expect(service.postRequests.last.before, isNull);
      expect(
        service.postRequests.last.category,
        ReportCategory.possibleInvasiveSpecies,
      );
    },
  );

  test('refresh supersedes a pending load of older posts', () async {
    service.posts = List.generate(12, (i) => publicPost('p$i'));
    await open();
    final older = Completer<List<FeedPost>>();
    service.onPosts = (_, before, _) async =>
        before == null ? [publicPost('fresh')] : older.future;
    final loading = vm().loadMore();
    await vm().refresh();
    older.complete([publicPost('stale')]);
    await loading;
    expect(container.read(provider).posts.single.id, 'fresh');
    expect(container.read(provider).isLoadingMore, isFalse);
  });

  test(
    'missing profile does not query reports; identity and gallery retry',
    () async {
      service.profile = null;
      await open();
      expect(container.read(provider).profile, isNull);
      expect(service.postRequests, isEmpty);
      service.profileError = StateError('offline');
      await vm().refresh();
      expect(container.read(provider).hasError, isTrue);
      service.profileError = null;
      service.profile = const ProfileData(username: 'Back online');
      service.postsError = StateError('offline');
      await vm().refresh();
      expect(container.read(provider).profile!.username, 'Back online');
      expect(container.read(provider).postsHaveError, isTrue);
      service.postsError = null;
      service.posts = [publicPost('a')];
      await vm().retryPosts();
      expect(container.read(provider).postsHaveError, isFalse);
      expect(container.read(provider).posts.single.id, 'a');
    },
  );

  test(
    'sign-out clears identity and signed media and rejects a late response',
    () async {
      service.posts = [publicPost('a')];
      await open();
      final pending = Completer<ProfileData?>();
      service.onProfile = (_) => pending.future;
      final refresh = vm().refresh();
      users.add(null);
      await pumpEventQueue();
      pending.complete(const ProfileData(username: 'Old account'));
      await refresh;
      expect(container.read(provider).profile, isNull);
      expect(container.read(provider).posts, isEmpty);
      final calls = service.profileRequests.length;
      await vm().refresh();
      expect(service.profileRequests.length, calls);
    },
  );

  test('signed-out access never calls the service', () async {
    await open(viewer: null);
    expect(service.profileRequests, isEmpty);
    expect(service.postRequests, isEmpty);
  });
}
