import 'package:flutter/material.dart';
import 'package:faunawatch/features/suspension/services/suspension_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/screens/gallery_post_viewer.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/post_management/services/post_management_service.dart';
import 'package:faunawatch/features/profile/models/profile_data.dart';
import 'package:faunawatch/features/report_detail/models/own_report.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';

import '../../feed/fake_feed_service.dart';
import '../fake_gallery_service.dart';
import '../../post_management/fake_post_management_service.dart';
import '../../feed/post_title_finder.dart';

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

  Future<void> pumpGallery(
    WidgetTester tester, {
    bool dark = false,
    List<Override> more = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        // Signed in but not suspended; the real service needs Supabase.
        suspensionServiceProvider.overrideWithValue(
          const SignedOutSuspensionService(),
        ),
        currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
        galleryServiceProvider.overrideWithValue(gallery),
        feedServiceProvider.overrideWithValue(service),
        profileViewModelProvider.overrideWith(_TestProfile.new),
        reportDetailServiceProvider.overrideWithValue(reports),
        ...more,
      ],
    );
    addTearDown(container.dispose);
    container
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.profile);
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
      expect(findPostTitle('My post 1'), findsOneWidget);
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
      expect(findPostTitle('My post 2'), findsOneWidget);
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
      expect(findPostTitle('My pending post'), findsOneWidget);
      // The owner's own name, not the report's placeholder author.
      expect(find.textContaining('Me · ', findRichText: true), findsOneWidget);
      expect(find.byType(PostStatusBadge), findsOneWidget);
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
      expect(findPostTitle('My post 2'), findsOneWidget);
      expect(find.byType(PostStatusBadge), findsNothing);
      staysInProfile();
    },
  );

  testWidgets(
    'declined posts show their badge and reason; likes explain they are '
    'closed',
    (tester) async {
      gallery.statuses['p1'] = ReportStatus.declined;
      reports.reports['p1'] = OwnReport(
        post: testPost('p1', authorId: 'me', title: 'My declined post'),
        status: ReportStatus.declined,
        declineReason: DeclineReason.duplicate,
      );
      await pumpGallery(tester);
      expect(find.text('Declined'), findsWidgets);
      await openPost(tester, 'p1');
      expect(findPostTitle('My declined post'), findsOneWidget);
      final badge = tester.widget<PostStatusBadge>(
        find.byType(PostStatusBadge),
      );
      expect(badge.status, ReportStatus.declined);
      expect(find.text('Reason: Duplicate report'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Like, 0'));
      await tester.pumpAndSettle();
      expect(find.text('This post was declined'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(service.likes, isEmpty);
      staysInProfile();
    },
  );

  testWidgets(
    'tapping the location of a pending post closes the viewer and shows its '
    'exact spot with the owner-only marker',
    (tester) async {
      gallery.statuses['p1'] = ReportStatus.pending;
      reports.reports['p1'] = OwnReport(
        post: testPost(
          'p1',
          authorId: 'me',
          title: 'My pending post',
          latitude: 16.46,
          longitude: 120.99,
        ),
        status: ReportStatus.pending,
      );
      reports.locations['p1'] = (latitude: 16.456789, longitude: 120.987654);
      await pumpGallery(tester);
      await openPost(tester, 'p1');
      await tester.tap(find.text('Lusod, Kabayan, Benguet'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPostViewer), findsNothing);
      expect(container.read(shellViewModelProvider), ShellDestination.map);
      final focus = container.read(communityMapViewModelProvider).privateFocus;
      expect(focus!.postId, 'p1');
      expect(focus.isPublic, isFalse);
      expect(focus.isExact, isTrue);
      expect(focus.latitude, 16.456789);
      expect(focus.longitude, 120.987654);
    },
  );

  testWidgets(
    'an approved own post opens at its exact spot, even without a rounded '
    'point from the feed',
    (tester) async {
      reports.locations['p0'] = (latitude: 10.316789, longitude: 123.891234);
      await pumpGallery(tester);
      await openPost(tester, 'p0');
      await tester.tap(find.text('Lusod, Kabayan, Benguet'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPostViewer), findsNothing);
      final focus = container.read(communityMapViewModelProvider).privateFocus;
      expect(focus!.isPublic, isTrue);
      expect(focus.isExact, isTrue);
      expect(focus.latitude, 10.316789);
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

  testWidgets('a hidden post shows its badge; deleting it from "⋯" returns '
      'to the grid', (tester) async {
    gallery.hidden.add('p1');
    final posts = FakePostManagementService();
    await pumpGallery(
      tester,
      more: [postManagementServiceProvider.overrideWithValue(posts)],
    );
    await openPost(tester, 'p1');
    expect(
      find.descendant(
        of: find.byType(GalleryPostViewer),
        matching: find.byType(HiddenPostBadge),
      ),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Post options'));
    await tester.pumpAndSettle();
    // Already hidden: it can be shown again, not hidden twice.
    expect(find.text('Show post again'), findsOneWidget);
    expect(find.text('Hide post'), findsNothing);
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(posts.deleted, ['p1']);
    expect(find.byType(GalleryPostViewer), findsNothing);
    expect(find.byType(GalleryCard), findsNWidgets(2));
    staysInProfile();
  });
}

class _FakeReportDetailService implements ReportDetailService {
  final locations = <String, ({double latitude, double longitude})>{};
  @override
  Future<({double latitude, double longitude})?> fetchOwnLocation(
    String reportId,
  ) async => locations[reportId];

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
