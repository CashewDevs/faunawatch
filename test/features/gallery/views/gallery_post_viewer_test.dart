import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/screens/gallery_post_viewer.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

import '../../feed/fake_feed_service.dart';
import '../fake_gallery_service.dart';

void main() {
  late FakeGalleryService gallery;
  late FakeFeedService service;
  late ProviderContainer container;
  late _FakeReportDetailService reports;

  setUp(() {
    reports = _FakeReportDetailService();
    gallery = FakeGalleryService(
      posts: [
        for (var i = 0; i < 3; i++)
          testPost('p$i', authorId: 'me', title: 'My post $i'),
      ],
    );
    service = FakeFeedService(posts: gallery.posts);
  });

  Future<void> pumpGallery(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
        galleryServiceProvider.overrideWithValue(gallery),
        feedServiceProvider.overrideWithValue(service),
        profileViewModelProvider.overrideWith(_TestProfile.new),
        reportDetailServiceProvider.overrideWithValue(reports),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.profile);
    container.read(feedTabViewModelProvider.notifier).select(FeedTab.map);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: const GalleryView(header: SizedBox(height: 600)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPost(WidgetTester tester, String id) async {
    final card = find.byWidgetPredicate(
      (w) => w is GalleryCard && w.item.id == id,
    );
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  void staysInProfile() {
    expect(container.read(shellViewModelProvider), ShellDestination.profile);
    expect(container.read(feedTabViewModelProvider), FeedTab.map);
  }

  testWidgets(
    'opens tapped post locally, swipes own posts and returns to grid position',
    (tester) async {
      await pumpGallery(tester);
      final card = find.byWidgetPredicate(
        (w) => w is GalleryCard && w.item.id == 'p1',
      );
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scroll.position.pixels;
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPostViewer), findsOneWidget);
      expect(find.text('My post 1'), findsOneWidget);
      expect(find.text('My posts'), findsOneWidget);
      staysInProfile();
      expect(service.pageRequests, isEmpty);
      await tester.fling(
        find.byWidgetPredicate(
          (w) => w is PageView && w.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -650),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('My post 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPostViewer), findsNothing);
      expect(find.byType(GalleryCard), findsNWidgets(3));
      expect(scroll.position.pixels, closeTo(offset, 1));
      staysInProfile();
    },
  );

  testWidgets(
    'loads full photos and supports likes and comments within Profile',
    (tester) async {
      service.posts[0] = service.posts[0].copyWith(
        photoUrls: [
          'https://photos.invalid/a.webp',
          'https://photos.invalid/b.webp',
        ],
      );
      service.comments = [testComment('c1', text: 'Great sighting!')];
      await pumpGallery(tester);
      await openPost(tester, 'p0');
      final card = tester.widget<FeedPostCard>(find.byType(FeedPostCard));
      expect(card.post.photoUrls, hasLength(2));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Like, 0'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Unlike, 1'), findsOneWidget);
      expect(service.likes, ['p0']);
      await tester.tap(find.bySemanticsLabel('Comments, 0'));
      await tester.pumpAndSettle();
      expect(find.text('Great sighting!'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My reply');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(service.added, ['My reply']);
      await tester.tap(find.byTooltip('Close comments'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Comments, 2'), findsOneWidget);
      staysInProfile();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed loads retry and withdrawn posts remain local', (
    tester,
  ) async {
    service.postError = Exception('offline');
    await pumpGallery(tester);
    await openPost(tester, 'p0');
    expect(find.text('Could not load this post.'), findsOneWidget);
    service.postError = null;
    service.posts = [];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('This post is no longer available.'), findsOneWidget);
    staysInProfile();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryCard), findsNWidgets(3));
  });

  testWidgets(
    'pending posts open in the swiping viewer; likes and comments explain '
    'they wait for approval',
    (tester) async {
      gallery.statuses['p1'] = ReportStatus.pending;
      reports.reports['p1'] = OwnReport(
        post: testPost(
          'p1',
          authorId: 'me',
          authorName: FeedPost.fallbackAuthorName,
          title: 'My pending post',
          photoUrls: ['https://photos.invalid/pending.webp'],
        ),
        status: ReportStatus.pending,
      );
      await pumpGallery(tester);
      await openPost(tester, 'p1');
      expect(find.byType(GalleryPostViewer), findsOneWidget);
      expect(find.text('My posts'), findsOneWidget);
      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(find.text('My pending post'), findsOneWidget);
      // The owner's own name, not the report's placeholder author.
      expect(find.textContaining('Me · ', findRichText: true), findsOneWidget);
      expect(find.byType(PendingReviewBadge), findsOneWidget);
      expect(reports.requests, ['p1']);
      expect(service.postRequests, isNot(contains('p1')));

      await tester.tap(find.bySemanticsLabel('Like, 0'));
      await tester.pumpAndSettle();
      expect(find.text('This post is still pending'), findsOneWidget);
      expect(
        find.textContaining("It's waiting for an admin's approval."),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(service.likes, isEmpty);

      await tester.tap(find.bySemanticsLabel('Comments, 0'));
      await tester.pumpAndSettle();
      expect(find.text('This post is still pending'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Great sighting!'), findsNothing);

      // Swiping continues through the approved posts around it.
      await tester.fling(
        find.byWidgetPredicate(
          (w) => w is PageView && w.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -650),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('My post 2'), findsOneWidget);
      expect(find.byType(PendingReviewBadge), findsNothing);
      staysInProfile();
    },
  );

  testWidgets('viewer supports the app dark theme', (tester) async {
    await pumpGallery(tester, dark: true);
    await openPost(tester, 'p0');
    expect(find.byType(FeedPostCard), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(GalleryPostViewer),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _FakeReportDetailService implements ReportDetailService {
  final reports = <String, OwnReport>{};
  final requests = <String>[];

  @override
  Future<OwnReport?> fetchOwnReport(String reportId) async {
    requests.add(reportId);
    return reports[reportId];
  }
}

class _TestProfile extends ProfileViewModel {
  @override
  Future<ProfileData> build() async => const ProfileData(username: 'Me');
}
