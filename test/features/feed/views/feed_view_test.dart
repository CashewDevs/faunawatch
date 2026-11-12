import 'dart:async';

import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/widgets/inset_centered_scroll.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/models/feed_state.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/feed/views/widgets/animated_heart.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_action_rail.dart';
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';
import 'package:faunawatch/features/feed/views/widgets/post_comments_sheet.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../fake_feed_service.dart';

void main() {
  late FakeFeedService service;

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  List<Override> overrides([List<Override> more = const []]) => [
    currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
    feedServiceProvider.overrideWithValue(service),
    ...more,
  ];

  Future<ProviderContainer> pumpFeed(
    WidgetTester tester, {
    ThemeData? theme,
    Widget? home,
    List<Override> more = const [],
  }) async {
    usePhone(tester);
    final container = ProviderContainer(overrides: overrides(more));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: theme, home: home ?? const FeedView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  FeedState readState(ProviderContainer container) =>
      container.read(feedViewModelProvider);

  setUp(() {
    service = FakeFeedService(
      posts: [
        testPost(
          'p0',
          likeCount: 128,
          commentCount: 6,
          description: 'Bird on the trail.',
        ),
      ],
    );
  });

  group('FeedView', () {
    testWidgets('shows the real post: author, title, text, area and tags', (
      tester,
    ) async {
      await pumpFeed(tester);
      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(find.text('Philippine Eagle'), findsOneWidget);
      expect(find.textContaining('spotter_one'), findsOneWidget);
      expect(find.text('Bird on the trail.'), findsOneWidget);
      expect(find.text('Lusod, Kabayan, Benguet'), findsOneWidget);
      expect(find.text('No posts yet.'), findsNothing);
      // The old sample's wording is gone.
      expect(find.text('Sample post'), findsNothing);
      expect(find.textContaining('Demo only'), findsNothing);
      expect(find.textContaining('Preliminary AI'), findsNothing);
    });

    testWidgets('shows Approximate location when there is no place name', (
      tester,
    ) async {
      service.posts = [testPost('p0', placeName: null)];
      await pumpFeed(tester);
      expect(find.text('Approximate location'), findsOneWidget);
    });

    testWidgets('AI details come with the preliminary note', (tester) async {
      service.posts = [
        testPost(
          'p0',
          title: 'Tarsier',
          severity: SeverityLevel.high,
          possibleInvasive: true,
          aiSpeciesGuess: 'Tarsier',
        ),
      ];
      await pumpFeed(tester);
      expect(find.text('Severity: High'), findsOneWidget);
      expect(find.text('Possible invasive species'), findsOneWidget);
      expect(find.text(FeedPost.aiNote), findsOneWidget);
    });

    testWidgets('a long description is collapsed until expanded', (
      tester,
    ) async {
      final text = List.filled(30, 'The bird stayed near the trees.').join(' ');
      service.posts = [testPost('p0', description: text)];
      await pumpFeed(tester);
      expect(find.text('more'), findsOneWidget);
      final collapsed = tester.getSize(find.text(text)).height;

      await tester.tap(find.text('more'));
      await tester.pump();
      expect(find.text('less'), findsOneWidget);
      expect(tester.getSize(find.text(text)).height, greaterThan(collapsed));
      await tester.ensureVisible(find.text('less'));
      await tester.tap(find.text('less'));
      await tester.pump();
      expect(tester.getSize(find.text(text)).height, collapsed);
    });

    testWidgets('a short description has no more button', (tester) async {
      await pumpFeed(tester);
      expect(find.text('more'), findsNothing);
    });

    testWidgets('photos are network images shown edge to edge', (tester) async {
      service.posts = [
        testPost(
          'p0',
          photoUrls: [
            'https://photos.invalid/a.webp',
            'https://photos.invalid/b.webp',
          ],
        ),
      ];
      await pumpFeed(tester);
      expect(
        tester.getSize(find.byType(PageView).last).width,
        tester.getSize(find.byType(FeedView)).width,
      );
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(FeedPostCard),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<NetworkImage>());
      expect(image.fit, BoxFit.fitWidth);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('a post without photos shows a placeholder', (tester) async {
      await pumpFeed(tester);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets(
      'keeps the post above the nav bar and the counter on the right',
      (tester) async {
        service.posts = [
          testPost(
            'p0',
            photoUrls: [
              'https://photos.invalid/a.webp',
              'https://photos.invalid/b.webp',
            ],
          ),
        ];
        await pumpFeed(
          tester,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 90),
            ),
            child: FeedView(),
          ),
        );
        final bottomLimit = tester.getBottomLeft(find.byType(FeedView)).dy - 90;
        expect(
          tester.getBottomLeft(find.text('Lusod, Kabayan, Benguet')).dy,
          lessThanOrEqualTo(bottomLimit),
        );
        expect(
          tester.getBottomLeft(find.bySemanticsLabel(RegExp('^Comments, '))).dy,
          lessThanOrEqualTo(bottomLimit),
        );
        expect(
          tester.getCenter(find.text('1 / 2')).dx,
          greaterThan(tester.getCenter(find.byType(FeedPostCard)).dx),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('matches the app theme instead of a fixed black background', (
      tester,
    ) async {
      for (final (theme, expected) in [
        (ThemeData.light(), Colors.white),
        (ThemeData.dark(), AppColors.darkBackground),
      ]) {
        await pumpFeed(tester, theme: theme);
        expect(
          tester
              .widget<Scaffold>(
                find.descendant(
                  of: find.byType(FeedView),
                  matching: find.byType(Scaffold),
                ),
              )
              .backgroundColor,
          expected,
        );
      }
    });

    testWidgets('dark mode renders the post without overflow', (tester) async {
      service.posts = [
        testPost('p0', severity: SeverityLevel.low, aiSpeciesGuess: 'x'),
      ];
      await pumpFeed(tester, theme: ThemeData.dark());
      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('states', () {
    testWidgets('shows a spinner while the first page loads', (tester) async {
      service.pageGate = Completer<void>();
      usePhone(tester);
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FeedView()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No posts yet.'), findsNothing);
      service.pageGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FeedPostCard), findsOneWidget);
    });

    testWidgets('an empty feed explains itself', (tester) async {
      service.posts = [];
      await pumpFeed(tester);
      expect(find.byType(BinocularsIcon), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
      expect(
        find.text(
          'Sightings and wildlife reports in your community will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed load shows an error and Try again reloads', (
      tester,
    ) async {
      service.pageError = Exception('offline');
      await pumpFeed(tester);
      expect(find.text('Could not load the feed.'), findsOneWidget);
      expect(find.text('No posts yet.'), findsNothing);

      service.pageError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(find.text('Could not load the feed.'), findsNothing);
    });

    testWidgets('the empty feed can be pulled to refresh', (tester) async {
      service.posts = [];
      await pumpFeed(tester);
      service.posts = [testPost('fresh', title: 'Fresh post')];
      await tester.fling(
        find.byType(InsetCenteredScroll),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh post'), findsOneWidget);
    });

    testWidgets('centres the empty feed above the nav bar inset', (
      tester,
    ) async {
      service.posts = [];
      const inset = 100.0;
      await pumpFeed(
        tester,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(bottom: inset),
          ),
          child: FeedView(),
        ),
      );
      final area = find.byType(InsetCenteredScroll);
      final visibleCentre =
          tester.getTopLeft(area).dy +
          (tester.getSize(area).height - inset) / 2;
      final content = find.descendant(of: area, matching: find.byType(Column));
      expect(tester.getCenter(content.first).dy, closeTo(visibleCentre, 1));
    });

    testWidgets('the empty feed does not overflow on a short screen', (
      tester,
    ) async {
      service.posts = [];
      await pumpFeed(
        tester,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(400, 260),
            padding: EdgeInsets.only(bottom: 80),
          ),
          child: FeedView(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('No posts yet.'), findsOneWidget);
    });
  });

  group('paging', () {
    setUp(() {
      service = FakeFeedService(
        posts: [
          for (var i = 0; i < 14; i++)
            testPost('p$i', index: i, title: 'Post $i'),
        ],
      );
    });

    testWidgets(
      'swipes up to the next post and loads older ones near the end',
      (tester) async {
        final container = await pumpFeed(tester);
        expect(find.text('Post 0'), findsOneWidget);
        expect(service.pageRequests, hasLength(1));

        Future<void> next() async {
          await tester.fling(
            find.byType(FeedPostCard),
            const Offset(0, -500),
            2000,
          );
          await tester.pumpAndSettle();
        }

        await next();
        expect(find.text('Post 1'), findsOneWidget);
        expect(find.text('Post 0'), findsNothing);
        for (var i = 0; i < 6; i++) {
          await next();
        }
        // Page 7 of 10: three posts are left, so the next page is requested.
        expect(find.text('Post 7'), findsOneWidget);
        expect(service.pageRequests, hasLength(2));
        expect(service.pageRequests.last!.id, 'p9');
        expect(readState(container).posts, hasLength(14));
      },
    );

    testWidgets('pull to refresh reloads the first page', (tester) async {
      await pumpFeed(tester);
      service.posts = [testPost('new', title: 'Brand new'), ...service.posts];
      await tester.fling(find.byType(FeedPostCard), const Offset(0, 500), 1000);
      await tester.pumpAndSettle();
      expect(service.pageRequests, hasLength(2));
      expect(find.text('Brand new'), findsOneWidget);
    });
  });

  group('likes', () {
    Icon heart(WidgetTester tester) => tester.widget<Icon>(
      find.descendant(
        of: find.byType(AnimatedHeart),
        matching: find.byType(Icon),
      ),
    );

    testWidgets('the rail has only the picture, like and comments', (
      tester,
    ) async {
      await pumpFeed(tester);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byType(PostAvatar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PostActionRail),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets("the rail shows the author's avatar and counts", (
      tester,
    ) async {
      service.posts = [
        testPost(
          'p0',
          likeCount: 1406,
          commentCount: 7,
          avatarAsset: AppAssets.avatarPanda,
        ),
      ];
      await pumpFeed(tester);
      final avatar = tester.widget<PostAvatar>(find.byType(PostAvatar));
      expect(avatar.asset, AppAssets.avatarPanda);
      expect(find.text('1.4K'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == "spotter_one's profile picture",
        ),
        findsOneWidget,
      );
    });

    testWidgets('liking turns the heart red, updates the count and saves', (
      tester,
    ) async {
      await pumpFeed(tester);
      expect(heart(tester).color, isNot(AppColors.feedLikeRed));
      expect(find.text('128'), findsOneWidget);

      await tester.tap(find.byType(AnimatedHeart));
      await tester.pumpAndSettle();
      expect(heart(tester).color, AppColors.feedLikeRed);
      expect(find.text('129'), findsOneWidget);
      expect(service.likes, ['p0']);

      await tester.tap(find.byType(AnimatedHeart));
      await tester.pumpAndSettle();
      expect(heart(tester).color, isNot(AppColors.feedLikeRed));
      expect(find.text('128'), findsOneWidget);
      expect(service.unlikes, ['p0']);
    });

    testWidgets('a post already liked by me starts red', (tester) async {
      service.posts = [testPost('p0', likeCount: 3, likedByMe: true)];
      await pumpFeed(tester);
      expect(heart(tester).color, AppColors.feedLikeRed);
    });

    testWidgets('a failed like is undone and the user is told', (tester) async {
      service.likeError = Exception('suspended');
      await pumpFeed(tester);
      await tester.tap(find.byType(AnimatedHeart));
      await tester.pumpAndSettle();
      expect(heart(tester).color, isNot(AppColors.feedLikeRed));
      expect(find.text('128'), findsOneWidget);
      expect(find.text('Could not update your like.'), findsOneWidget);
    });
  });

  group('comments sheet', () {
    setUp(() {
      service.comments = [
        testComment('c2', authorName: 'bird_notes', text: 'Did it stay long?'),
        testComment('c1', text: 'Great spot!'),
      ];
    });

    Future<void> openComments(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.sms));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the real comments with their authors', (tester) async {
      await pumpFeed(tester);
      await openComments(tester);
      expect(find.text('2 comments'), findsOneWidget);
      expect(find.text('Did it stay long?'), findsOneWidget);
      expect(find.text('Great spot!'), findsOneWidget);
      expect(find.textContaining('bird_notes'), findsOneWidget);
      expect(find.textContaining('trail_walker'), findsOneWidget);
      expect(find.byTooltip('Close comments'), findsOneWidget);
    });

    testWidgets('has no replies, reactions, photos, mentions or sorting', (
      tester,
    ) async {
      await pumpFeed(tester);
      await openComments(tester);
      expect(find.text('Reply'), findsNothing);
      expect(find.textContaining('replies'), findsNothing);
      expect(find.byTooltip('Sort comments'), findsNothing);
      expect(find.byIcon(Icons.thumb_down_outlined), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Like comment')), findsNothing);
      expect(find.bySemanticsLabel('Add photo'), findsNothing);
      expect(find.bySemanticsLabel('Mention someone'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PostCommentsSheet),
          matching: find.byIcon(Icons.image_outlined),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.alternate_email), findsNothing);
      expect(find.text('Creator'), findsNothing);
      // Plain text and emoji remain.
      expect(find.bySemanticsLabel('Add emoji'), findsOneWidget);
    });

    testWidgets('posts a comment, lists it first and updates the count', (
      tester,
    ) async {
      await pumpFeed(tester);
      await openComments(tester);
      await tester.enterText(find.byType(TextField), '  Lovely bird  ');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(service.added, ['Lovely bird']);
      expect(find.text('Lovely bird'), findsOneWidget);
      expect(find.text('3 comments'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      // The post's rail count follows the sheet: 2 loaded + the new one.
      await tester.tap(find.byTooltip('Close comments'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Comments, 3'), findsOneWidget);
    });

    testWidgets('a failed post keeps the text and shows why', (tester) async {
      service.addError = Exception('suspended');
      await pumpFeed(tester);
      await openComments(tester);
      await tester.enterText(find.byType(TextField), 'Hello there');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not post your comment. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello there',
      );
      expect(find.text('2 comments'), findsOneWidget);
    });

    testWidgets('shows an empty state', (tester) async {
      service.comments = [];
      await pumpFeed(tester);
      await openComments(tester);
      expect(find.text('0 comments'), findsOneWidget);
      expect(find.text('No comments yet. Be the first!'), findsOneWidget);
    });

    testWidgets('shows an error with Retry', (tester) async {
      service.commentsError = Exception('offline');
      await pumpFeed(tester);
      await openComments(tester);
      expect(find.text('Could not load comments.'), findsOneWidget);
      service.commentsError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Great spot!'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await pumpFeed(tester, theme: ThemeData.dark());
      await openComments(tester);
      expect(find.text('Great spot!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tabs', () {
    testWidgets('Your Gallery tab shows gallery cards and filters them', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        more: [galleryServiceProvider.overrideWithValue(_FakeGalleryService())],
      );
      expect(find.byType(GalleryCard), findsNothing);

      await tester.tap(find.text('Your Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryView), findsOneWidget);
      expect(find.byType(GalleryCard), findsNWidgets(2));

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Birds'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryCard), findsOneWidget);
      expect(find.text('Barn Owl'), findsOneWidget);
    });

    testWidgets('Map tab creates one map and keeps it across tab switches', (
      tester,
    ) async {
      final canvas = _FakeMapCanvasBuilder();
      await pumpFeed(
        tester,
        more: [
          mapboxMapCanvasBuilderProvider.overrideWithValue(canvas),
          mapboxMapServiceProvider.overrideWithValue(_FakeMapService()),
        ],
      );
      expect(canvas.builds, 0);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsOneWidget);
      expect(find.text('Community map'), findsOneWidget);
      final state = tester.state(find.byType(CommunityMapView));

      await tester.tap(find.text('For You'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityMapView), findsNothing);
      expect(find.byType(FeedPostCard), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CommunityMapView)), same(state));
    });

    testWidgets('a report opened from the map shows its post in For You', (
      tester,
    ) async {
      service.posts = [
        testPost('p0', title: 'First'),
        testPost('p1', index: 1, title: 'Second post'),
        testPost('p2', index: 2, title: 'Third post'),
      ];
      final container = await pumpFeed(
        tester,
        more: [
          mapboxMapCanvasBuilderProvider.overrideWithValue(
            _FakeMapCanvasBuilder(),
          ),
          mapboxMapServiceProvider.overrideWithValue(_FakeMapService()),
          communityReportsServiceProvider.overrideWithValue(
            _FakeReports([
              const CommunityReport(
                id: 'p2',
                category: 'animal_in_need',
                latitude: 10.1,
                longitude: 123.9,
                description: 'Third report',
              ),
            ]),
          ),
        ],
      );
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      final map = container.read(communityMapViewModelProvider.notifier);
      await map.onStyleLoaded();

      map.selectPost('p2');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See more in feed'));
      await tester.tap(find.text('See more in feed'));
      await tester.pumpAndSettle();

      expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
      expect(find.text('Third post'), findsOneWidget);
      expect(find.text('First'), findsNothing);
      expect(find.text('See more in feed'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header shows the tabs in the feed, not the header', (
      tester,
    ) async {
      await pumpFeed(tester);
      for (final label in ['Your Gallery', 'Map', 'For You']) {
        expect(
          find.descendant(
            of: find.byType(FeedView),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('the shell header shows the logo and the wordmark', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(appBar: ShellHeader())),
      );
      bool showsAsset(Widget widget, String asset) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset;
      final header = find.byType(ShellHeader);
      for (final asset in [AppAssets.appLogo, AppAssets.appWordmark]) {
        expect(
          find.descendant(
            of: header,
            matching: find.byWidgetPredicate(
              (widget) => showsAsset(widget, asset),
            ),
          ),
          findsOneWidget,
        );
      }
    });
  });
}

class _FakeGalleryService implements GalleryService {
  @override
  Future<List<GalleryItem>> fetchGalleryItems() async => const [
    GalleryItem(id: '1', title: 'Barn Owl', category: 'Birds', date: 'Oct 19'),
    GalleryItem(id: '2', title: 'Red Fox', category: 'Mammals', date: 'Oct 19'),
  ];
}

class _FakeReports implements CommunityReportsService {
  const _FakeReports(this.reports);
  final List<CommunityReport> reports;

  @override
  Future<List<CommunityReport>> load() async => reports;
}

class _FakeMapCanvasBuilder implements MapboxMapCanvasBuilder {
  int builds = 0;

  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
  }) {
    builds++;
    return const SizedBox(key: Key('fake_mapbox_map'));
  }
}

class _FakeMapService implements MapboxMapService {
  @override
  Future<void> showReports(List<CommunityReport> reports) async {}
  @override
  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  }) async {}

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {}

  @override
  void detach() {}

  @override
  Future<void> showWarningDemo(
    DemoWarningLevel level, {
    bool recenter = false,
  }) async {}
}
