import 'package:flutter/material.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faunawatch/features/feed/views/feed_view.dart';
import 'package:faunawatch/features/feed/views/widgets/animated_heart.dart';
import 'package:faunawatch/features/feed/views/widgets/binoculars_icon.dart';
import 'package:faunawatch/features/feed/views/widgets/feed_post_card.dart';
import 'package:faunawatch/features/feed/views/widgets/post_action_rail.dart';
import 'package:faunawatch/features/shell/views/widgets/shell_header.dart';
import 'package:faunawatch/features/gallery/models/gallery_item.dart';
import 'package:faunawatch/features/gallery/services/gallery_service.dart';
import 'package:faunawatch/features/gallery/views/gallery_view.dart';
import 'package:faunawatch/features/gallery/views/widgets/gallery_card.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:faunawatch/features/feed/views/widgets/post_avatar.dart';

void main() {
  ProviderContainer openSampleContainer() {
    final container = ProviderContainer();
    container
        .read(feedViewModelProvider.notifier)
        .openSamplePost(sampleMapPost.id);
    return container;
  }

  Future<void> pumpSamplePost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = openSampleContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FeedView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FeedView', () {
    testWidgets('shows the full sample post selected from the map', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(feedViewModelProvider.notifier)
          .openSamplePost(sampleMapPost.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FeedView()),
        ),
      );
      expect(find.text(sampleMapPost.title), findsOneWidget);
      expect(find.text(sampleMapPost.body), findsNothing);
      expect(find.text('No posts yet.'), findsNothing);
      expect(
        find.text('Demo only - Not a real wildlife report'),
        findsOneWidget,
      );
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.tap(find.text('more'));
      await tester.pump();
      expect(find.text(sampleMapPost.body), findsOneWidget);
      await tester.tap(find.text('less'));
      await tester.pump();
      expect(find.text(sampleMapPost.body), findsNothing);
    });
    testWidgets(
      'keeps the post above the nav bar and the counter on the right',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(feedViewModelProvider.notifier)
            .openSamplePost(sampleMapPost.id);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(390, 844),
                  padding: EdgeInsets.only(bottom: 90),
                ),
                child: FeedView(),
              ),
            ),
          ),
        );
        final bottomLimit = tester.getBottomLeft(find.byType(FeedView)).dy - 90;
        expect(
          tester
              .getBottomLeft(
                find.text('Demo only - Not a real wildlife report'),
              )
              .dy,
          lessThanOrEqualTo(bottomLimit),
        );
        expect(
          tester.getBottomLeft(find.bySemanticsLabel(RegExp('^Comments, '))).dy,
          lessThanOrEqualTo(bottomLimit),
        );
        expect(
          tester.getCenter(find.text('1 / 3')).dx,
          greaterThan(tester.getCenter(find.byType(PageView)).dx),
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
        final container = openSampleContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: theme, home: const FeedView()),
          ),
        );
        await tester.pumpAndSettle();
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
    testWidgets('shows photos edge to edge', (tester) async {
      await pumpSamplePost(tester);
      expect(
        tester.getSize(find.byType(PageView)).width,
        tester.getSize(find.byType(FeedView)).width,
      );
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .where((image) => image.fit == BoxFit.fitWidth),
        isNotEmpty,
      );
    });
    testWidgets('rail has only the picture, like and comments, no backing', (
      tester,
    ) async {
      await pumpSamplePost(tester);
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
    testWidgets('liking a post turns the heart red and updates the count', (
      tester,
    ) async {
      await pumpSamplePost(tester);
      Icon heart() => tester.widget<Icon>(
        find.descendant(
          of: find.byType(AnimatedHeart),
          matching: find.byType(Icon),
        ),
      );
      expect(heart().color, isNot(AppColors.feedLikeRed));
      expect(find.text('128'), findsOneWidget);

      await tester.tap(find.byType(AnimatedHeart));
      await tester.pumpAndSettle();
      expect(heart().color, AppColors.feedLikeRed);
      expect(find.text('129'), findsOneWidget);

      await tester.tap(find.byType(AnimatedHeart));
      await tester.pumpAndSettle();
      expect(heart().color, isNot(AppColors.feedLikeRed));
      expect(find.text('128'), findsOneWidget);
    });
    testWidgets('posts a comment and a reply from the comment sheet', (
      tester,
    ) async {
      await pumpSamplePost(tester);
      await tester.tap(find.byIcon(Icons.sms));
      await tester.pumpAndSettle();
      expect(find.text('6 comments'), findsOneWidget);
      expect(find.byTooltip('Sort comments'), findsOneWidget);
      expect(
        tester.getCenter(find.byTooltip('Close comments')).dx,
        greaterThan(tester.getCenter(find.byTooltip('Sort comments')).dx + 48),
      );
      expect(
        find.text('Thanks! It was close to the main walking loop.'),
        findsOneWidget,
      );
      expect(find.text('I want to walk there this weekend.'), findsNothing);

      await tester.tap(find.text('View 1 reply').first);
      await tester.pumpAndSettle();
      expect(find.text('I want to walk there this weekend.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Lovely bird  ');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(find.text('Lovely bird'), findsOneWidget);
      expect(find.text('7 comments'), findsOneWidget);

      await tester.tap(find.text('Reply').first);
      await tester.pumpAndSettle();
      expect(find.text('Replying to You'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Replying here');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(find.text('Replying here'), findsOneWidget);
      expect(find.text('8 comments'), findsOneWidget);
      expect(find.text('Replying to You'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Your Gallery tab shows gallery cards and filters them', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            galleryServiceProvider.overrideWithValue(_FakeGalleryService()),
          ],
          child: const MaterialApp(home: FeedView()),
        ),
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapboxMapCanvasBuilderProvider.overrideWithValue(canvas),
            mapboxMapServiceProvider.overrideWithValue(_FakeMapService()),
          ],
          child: const MaterialApp(home: FeedView()),
        ),
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
      expect(find.text('No posts yet.'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CommunityMapView)), same(state));
    });
    testWidgets('a post opened from the map tab shows in For You', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          mapboxMapCanvasBuilderProvider.overrideWithValue(
            _FakeMapCanvasBuilder(),
          ),
          mapboxMapServiceProvider.overrideWithValue(_FakeMapService()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FeedView()),
        ),
      );
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();

      container
          .read(communityMapViewModelProvider.notifier)
          .selectPost(sampleMapPost.id);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See more in feed'));
      await tester.tap(find.text('See more in feed'));
      await tester.pumpAndSettle();

      expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(find.text('See more in feed'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('header shows the logo and the wordmark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(appBar: ShellHeader())),
      );

      bool showsAsset(Widget widget, String asset) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset;

      final header = find.byType(ShellHeader);
      expect(
        find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
            (widget) => showsAsset(widget, AppAssets.appLogo),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
            (widget) => showsAsset(widget, AppAssets.appWordmark),
          ),
        ),
        findsOneWidget,
      );
    });
    testWidgets('shows the tabs in the feed, not the header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: FeedView())),
      );

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
    testWidgets('renders binoculars silhouette, title, and descriptive text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: FeedView())),
      );

      expect(find.byType(BinocularsIcon), findsOneWidget);
      expect(find.text('No posts yet.'), findsOneWidget);
      expect(
        find.text(
          'Sightings and wildlife reports in your community will appear here.',
        ),
        findsOneWidget,
      );
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
