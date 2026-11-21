import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/feed/models/post_comment.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_post_viewmodel.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

import '../../feed/fake_feed_service.dart';

void main() {
  late ProviderContainer container;
  late FakeFeedService service;
  final provider = galleryPostViewModelProvider((
    id: 'own',
    status: ReportStatus.approved,
    authorId: null,
  ));

  Future<void> open({String? user = 'me'}) async {
    container = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWithValue(service),
        currentUserIdProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentUserIdProvider.future);
    container.listen(provider, (_, _) {});
    container
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.profile);
    container.read(feedTabViewModelProvider.notifier).select(FeedTab.map);
    expect(container.read(provider).isLoading, isTrue);
    await pumpEventQueue();
  }

  GalleryPostViewModel vm() => container.read(provider.notifier);

  setUp(() {
    service = FakeFeedService(
      posts: [
        testPost(
          'own',
          authorId: 'me',
          likeCount: 4,
          commentCount: 150,
          photoUrls: [
            'https://photos.invalid/one.webp',
            'https://photos.invalid/two.webp',
          ],
        ),
      ],
    );
  });

  test('loads the full own post without moving or loading the feed', () async {
    await open();
    expect(container.read(provider).post!.photoUrls, hasLength(2));
    expect(container.read(provider).isLoading, isFalse);
    expect(service.postRequests, ['own']);
    expect(service.pageRequests, isEmpty);
    expect(container.read(shellViewModelProvider), ShellDestination.profile);
    expect(container.read(feedTabViewModelProvider), FeedTab.map);
  });

  test('missing and other users posts are unavailable', () async {
    service.posts = [testPost('own', authorId: 'someone-else')];
    await open();
    expect(container.read(provider).post, isNull);
    expect(container.read(provider).hasError, isFalse);
    service.posts = [];
    await vm().retry();
    expect(container.read(provider).post, isNull);
  });

  test('signed-out viewers do not fetch a post', () async {
    await open(user: null);
    expect(service.postRequests, isEmpty);
    expect(container.read(provider).post, isNull);
    expect(container.read(provider).isLoading, isFalse);
  });

  test(
    'public gallery loads only its selected author and keeps likes local',
    () async {
      service.posts = [testPost('own', authorId: 'other', likeCount: 4)];
      await open();
      final public = galleryPostViewModelProvider((
        id: 'own',
        status: ReportStatus.approved,
        authorId: 'other',
      ));
      container.listen(public, (_, _) {});
      await pumpEventQueue();
      expect(container.read(public).post!.authorId, 'other');
      await container.read(public.notifier).toggleLike();
      expect(service.likes, ['own']);
      expect(container.read(public).post!.likeCount, 5);
      expect(service.pageRequests, isEmpty);
      service.posts = [testPost('own', authorId: 'wrong')];
      await container.read(public.notifier).retry();
      expect(container.read(public).post, isNull);
    },
  );

  for (final status in [ReportStatus.pending, ReportStatus.declined]) {
    test(
      'a public gallery reference cannot load a private ${status.name} report',
      () async {
        await open();
        service.postRequests.clear();
        final public = galleryPostViewModelProvider((
          id: 'private',
          status: status,
          authorId: 'other',
        ));
        container.listen(public, (_, _) {});
        await pumpEventQueue();
        expect(container.read(public).post, isNull);
        expect(container.read(public).hasError, isFalse);
        expect(service.postRequests, isEmpty);
      },
    );
  }

  test('failed load can retry without leaving Profile', () async {
    service.postError = Exception('offline');
    await open();
    expect(container.read(provider).hasError, isTrue);
    service.postError = null;
    await vm().retry();
    expect(container.read(provider).post!.id, 'own');
    expect(container.read(provider).hasError, isFalse);
  });

  test('likes are optimistic, ignore duplicate taps and can unlike', () async {
    await open();
    final gate = Completer<void>();
    service.likeGate = gate;
    final saving = vm().toggleLike();
    expect(container.read(provider).post!.likedByMe, isTrue);
    expect(container.read(provider).post!.likeCount, 5);
    await vm().toggleLike();
    expect(service.likes, ['own']);
    gate.complete();
    await saving;
    await vm().toggleLike();
    expect(service.unlikes, ['own']);
    expect(container.read(provider).post!.likeCount, 4);
  });

  test(
    'a failed like rolls back and keeps concurrently updated comments',
    () async {
      await open();
      final gate = Completer<void>();
      service.likeGate = gate;
      service.likeError = Exception('offline');
      final saving = vm().toggleLike();
      vm().commentsChanged(
        null,
        PostCommentsState(comments: [testComment('c')]),
      );
      gate.complete();
      await saving;
      final state = container.read(provider);
      expect(state.post!.likedByMe, isFalse);
      expect(state.post!.likeCount, 4);
      expect(state.post!.commentCount, 1);
      expect(state.message, 'Could not update your like.');
      vm().clearMessage();
      expect(container.read(provider).message, isNull);
    },
  );

  test(
    'comment totals preserve unloaded comments and count successful sends',
    () async {
      await open();
      final comments = [for (var i = 0; i < 100; i++) testComment('c$i')];
      final loaded = PostCommentsState(comments: comments);
      vm().commentsChanged(null, loaded);
      expect(container.read(provider).post!.commentCount, 150);
      vm().commentsChanged(
        loaded.copyWith(isSending: true),
        loaded.copyWith(comments: [testComment('new'), ...comments]),
      );
      expect(container.read(provider).post!.commentCount, 151);
      vm().commentsChanged(null, const PostCommentsState(hasError: true));
      expect(container.read(provider).post!.commentCount, 151);
      vm().commentsChanged(null, const PostCommentsState());
      expect(container.read(provider).post!.commentCount, 0);
    },
  );

  test('account changes discard a pending post and its signed URLs', () async {
    final owner = StateProvider<String?>((ref) => 'me');
    final gate = Completer<void>();
    service.postGate = gate;
    container = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWithValue(service),
        currentUserIdProvider.overrideWith(
          (ref) => Stream.value(ref.watch(owner)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentUserIdProvider.future);
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
    container.read(owner.notifier).state = 'different-user';
    await pumpEventQueue();
    gate.complete();
    await pumpEventQueue();
    expect(container.read(provider).post, isNull);
    expect(container.read(provider).isLoading, isFalse);
  });

  test(
    'late comment-sheet callbacks are ignored after the page is disposed',
    () async {
      await open();
      final viewModel = vm();
      container.invalidate(provider);
      expect(
        () => viewModel.commentsChanged(null, const PostCommentsState()),
        returnsNormally,
      );
    },
  );

  group('pending posts', () {
    late _FakeReports reports;
    final pending = galleryPostViewModelProvider((
      id: 'own',
      status: ReportStatus.pending,
      authorId: null,
    ));

    Future<GalleryPostState> openPending(
      ReportStatus status, {
      DeclineReason? reason,
    }) async {
      reports = _FakeReports()
        ..report = OwnReport(
          post: testPost('own', authorId: 'me', authorName: 'FaunaWatch user'),
          status: status,
          declineReason: reason,
        );
      container = ProviderContainer(
        overrides: [
          feedServiceProvider.overrideWithValue(service),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          reportDetailServiceProvider.overrideWithValue(reports),
          profileViewModelProvider.overrideWith(_Profile.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserIdProvider.future);
      container.listen(pending, (_, _) {});
      await pumpEventQueue();
      return container.read(pending);
    }

    test('load through the owner report with the own profile name', () async {
      final state = await openPending(ReportStatus.pending);
      expect(state.isPending, isTrue);
      expect(state.post!.id, 'own');
      expect(state.post!.authorName, 'Owner');
      expect(state.post!.authorAvatarAsset, 'fox');
      expect(reports.requests, ['own']);
      expect(service.postRequests, isEmpty);
    });

    test('cannot be liked', () async {
      await openPending(ReportStatus.pending);
      await container.read(pending.notifier).toggleLike();
      expect(service.likes, isEmpty);
      expect(container.read(pending).post!.likedByMe, isFalse);
    });

    test('approved meanwhile load from the feed with likes', () async {
      final state = await openPending(ReportStatus.approved);
      expect(state.isPending, isFalse);
      expect(state.post!.likeCount, 4);
      expect(service.postRequests, ['own']);
    });

    test('declined meanwhile show as declined with the reason', () async {
      final state = await openPending(
        ReportStatus.declined,
        reason: DeclineReason.notWildlife,
      );
      expect(state.isDeclined, isTrue);
      expect(state.isPublic, isFalse);
      expect(state.declineReason, DeclineReason.notWildlife);
      expect(state.post!.authorName, 'Owner');
      expect(service.postRequests, isEmpty);
    });

    test('changes requested meanwhile are no longer available', () async {
      final state = await openPending(ReportStatus.changesRequested);
      expect(state.post, isNull);
      expect(state.hasError, isFalse);
      expect(service.postRequests, isEmpty);
    });
  });

  group('declined posts', () {
    const declined = (id: 'own', status: ReportStatus.declined, authorId: null);
    late _FakeReports reports;

    Future<void> openDeclined() async {
      reports = _FakeReports()
        ..report = OwnReport(
          post: testPost('own', authorId: 'me'),
          status: ReportStatus.declined,
          declineReason: DeclineReason.duplicate,
        );
      container = ProviderContainer(
        overrides: [
          feedServiceProvider.overrideWithValue(service),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          reportDetailServiceProvider.overrideWithValue(reports),
          profileViewModelProvider.overrideWith(_Profile.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserIdProvider.future);
      container.listen(galleryPostViewModelProvider(declined), (_, _) {});
      await pumpEventQueue();
    }

    test('load through the owner report and cannot be liked', () async {
      await openDeclined();
      final provider = galleryPostViewModelProvider(declined);
      expect(container.read(provider).declineReason, DeclineReason.duplicate);
      expect(reports.requests, ['own']);
      await container.read(provider.notifier).toggleLike();
      expect(service.likes, isEmpty);
      expect(container.read(provider).post!.likedByMe, isFalse);
    });
  });
}

class _FakeReports implements ReportDetailService {
  final locations = <String, ({double latitude, double longitude})>{};
  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async => locations[reportId];

  OwnReport? report;
  final requests = <String>[];

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async {
    requests.add(reportId);
    return report;
  }
}

class _Profile extends ProfileViewModel {
  @override
  Future<ProfileData> build() async =>
      const ProfileData(username: 'Owner', presetAvatar: 'fox');
}
