import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/report_detail/viewmodels/report_detail_viewmodel.dart';

import '../../feed/fake_feed_service.dart';

class FakeReportDetailService implements ReportDetailService {
  OwnReport? report;
  Object? error;
  final requests = <String>[];

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async {
    requests.add(reportId);
    if (error != null) throw error!;
    return report;
  }
}

void main() {
  late FakeReportDetailService service;
  late FakeFeedService feed;
  late ProviderContainer container;
  final provider = reportDetailViewModelProvider('r1');

  Future<void> open() async {
    container = ProviderContainer(
      overrides: [
        reportDetailServiceProvider.overrideWithValue(service),
        feedServiceProvider.overrideWithValue(feed),
      ],
    );
    addTearDown(container.dispose);
    container.listen(provider, (_, _) {});
    expect(container.read(provider).isLoading, isTrue);
    await pumpEventQueue();
  }

  ReportDetailViewModel vm() => container.read(provider.notifier);

  setUp(() {
    service = FakeReportDetailService();
    feed = FakeFeedService(posts: []);
  });

  for (final status in [
    ReportStatus.pending,
    ReportStatus.declined,
    ReportStatus.changesRequested,
  ]) {
    test('shows an own ${status.name} report without the feed', () async {
      service.report = OwnReport(post: testPost('r1'), status: status);

      await open();

      expect(container.read(provider).report?.status, status);
      expect(container.read(provider).notFound, isFalse);
      expect(feed.postRequests, isEmpty);
    });
  }

  test('an approved report gets likes and comments from the feed', () async {
    service.report = OwnReport(
      post: testPost('r1', photoUrls: const ['own-photo']),
      status: ReportStatus.approved,
    );
    feed.posts = [testPost('r1', likeCount: 4, commentCount: 2)];

    await open();

    final post = container.read(provider).report!.post;
    expect(post.likeCount, 4);
    expect(post.commentCount, 2);
    expect(post.photoUrls, ['own-photo']);
  });

  test('an approved report still shows when the feed fails', () async {
    service.report = OwnReport(
      post: testPost('r1'),
      status: ReportStatus.approved,
    );
    feed.postError = StateError('offline');

    await open();

    expect(container.read(provider).report, isNotNull);
    expect(container.read(provider).hasError, isFalse);
  });

  test('a missing or deleted report is reported as not found', () async {
    await open();

    final state = container.read(provider);
    expect(state.notFound, isTrue);
    expect(state.report, isNull);
    expect(state.hasError, isFalse);
  });

  test('a load failure can be retried', () async {
    service.error = StateError('offline');
    await open();
    expect(container.read(provider).hasError, isTrue);
    expect(container.read(provider).notFound, isFalse);

    service.error = null;
    service.report = OwnReport(
      post: testPost('r1'),
      status: ReportStatus.pending,
    );
    await vm().retry();

    expect(container.read(provider).report?.status, ReportStatus.pending);
    expect(container.read(provider).hasError, isFalse);
  });

  test('likes optimistically and rolls back on failure', () async {
    service.report = OwnReport(
      post: testPost('r1'),
      status: ReportStatus.approved,
    );
    feed.posts = [testPost('r1', likeCount: 1)];
    await open();

    await vm().toggleLike();
    expect(feed.likes, ['r1']);
    expect(container.read(provider).report!.post.likeCount, 2);
    expect(container.read(provider).report!.post.likedByMe, isTrue);

    feed.likeError = StateError('nope');
    await vm().toggleLike();
    expect(container.read(provider).report!.post.likeCount, 2);
    expect(container.read(provider).report!.post.likedByMe, isTrue);
    expect(container.read(provider).message, 'Could not update your like.');
  });

  test('a report that is not approved cannot be liked', () async {
    service.report = OwnReport(
      post: testPost('r1'),
      status: ReportStatus.pending,
    );
    await open();

    await vm().toggleLike();

    expect(feed.likes, isEmpty);
  });

  test('status maps from the database value', () {
    expect(ReportStatus.fromDb('pending'), ReportStatus.pending);
    expect(
      ReportStatus.fromDb('changes_requested'),
      ReportStatus.changesRequested,
    );
    expect(ReportStatus.fromDb('approved'), ReportStatus.approved);
    expect(ReportStatus.fromDb('declined'), ReportStatus.declined);
    expect(ReportStatus.fromDb('submitted'), ReportStatus.other);
  });
}
