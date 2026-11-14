import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_post_dialog.dart';
import 'package:faunawatch/features/community_map/viewmodels/community_map_viewmodel.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/services/community_reports_service.dart';
import 'package:faunawatch/features/feed/services/feed_service.dart';
import '../../feed/fake_feed_service.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_guide_sheet.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_purpose_card.dart';

void main() {
  Widget buildMap({
    ThemeData? theme,
    double textScale = 1,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        mapboxMapCanvasBuilderProvider.overrideWithValue(
          _FakeMapboxMapCanvasBuilder(),
        ),
        mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
        currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CommunityMapView(),
      ),
    );
  }

  testWidgets('a report pin opens its post in the feed through see more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildMap(
        theme: ThemeData.dark(useMaterial3: true),
        textScale: 1.5,
        extraOverrides: [
          communityReportsServiceProvider.overrideWithValue(
            _FakeReports(const [
              CommunityReport(
                id: 'r1',
                category: 'animal_in_need',
                latitude: 10.12,
                longitude: 123.12,
                description: 'Bird near the road.',
              ),
            ]),
          ),
          feedServiceProvider.overrideWithValue(
            FakeFeedService(posts: [testPost('r1', title: 'Bird')]),
          ),
        ],
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CommunityMapView)),
    );
    final vm = container.read(communityMapViewModelProvider.notifier);
    await vm.onStyleLoaded();
    vm.selectPost('r1');
    await tester.pumpAndSettle();
    expect(find.byType(MapPostDialog), findsOneWidget);
    expect(find.text('Approved wildlife report'), findsOneWidget);
    expect(find.text('Sample post'), findsNothing);
    expect(find.text('Bird near the road.'), findsOneWidget);

    await tester.ensureVisible(find.text('See more in feed'));
    await tester.tap(find.text('See more in feed'));
    await tester.pumpAndSettle();
    expect(container.read(shellViewModelProvider), ShellDestination.feed);
    expect(container.read(feedTabViewModelProvider), FeedTab.forYou);
    expect(container.read(feedViewModelProvider).focusedPostId, 'r1');
    expect(find.text('See more in feed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty map shows no approved reports and can refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildMap(
        extraOverrides: [
          communityReportsServiceProvider.overrideWithValue(
            const _FakeReports([]),
          ),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CommunityMapView)),
    );
    await container
        .read(communityMapViewModelProvider.notifier)
        .onStyleLoaded();
    await tester.pump();
    expect(find.text('No approved reports yet · Refresh'), findsOneWidget);
    await tester.tap(find.text('No approved reports yet · Refresh'));
    await tester.pumpAndSettle();
    expect(container.read(communityMapViewModelProvider).reports, isEmpty);
    expect(find.textContaining('Sample incident'), findsNothing);
    expect(find.byType(MapPostDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains real approved reports without demo content', (
    tester,
  ) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    expect(find.byType(MapPurposeCard), findsOneWidget);
    expect(find.text('Wildlife encounters, on one shared map'), findsOneWidget);
    expect(
      find.textContaining('FaunaWatch logo pins show approved posts'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('How this map works'));
    await tester.tap(find.text('How this map works'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsOneWidget);
    expect(find.text('Find reported encounters'), findsOneWidget);
    expect(
      find.textContaining(
        'Approved reports appear as FaunaWatch logo pins at approximate locations.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('Danger Zone'), findsNothing);
    await tester.tap(find.byTooltip('Close map guide'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsNothing);
    expect(find.byKey(const Key('fake_mapbox_map')), findsOneWidget);
    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.text('2D'), findsOneWidget);
  });

  testWidgets('map information dismisses and reopens without demo controls', (
    tester,
  ) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    await tester.tap(find.byTooltip('Dismiss map information'));
    await tester.pump();
    expect(find.byType(MapPurposeCard), findsNothing);
    expect(find.textContaining('Warning demo'), findsNothing);
    await tester.tap(find.byTooltip('About this map'));
    await tester.pump();
    expect(find.byType(MapPurposeCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guide remains reachable on a small dark screen with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildMap(theme: ThemeData.dark(useMaterial3: true), textScale: 1.5),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('How this map works'));
      await tester.tap(find.text('How this map works'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Try it now:'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Close map guide'));
      await tester.tap(find.byTooltip('Close map guide'));
      await tester.pumpAndSettle();
      expect(find.byType(MapGuideSheet), findsNothing);
      await tester.tap(find.byTooltip('Dismiss map information'));
      await tester.pump();
      expect(find.textContaining('simulated'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps the initial viewport when changing map dimension', (
    tester,
  ) async {
    final canvasBuilder = _FakeMapboxMapCanvasBuilder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapboxMapCanvasBuilderProvider.overrideWithValue(canvasBuilder),
          mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
        ],
        child: const MaterialApp(home: CommunityMapView()),
      ),
    );
    await tester.pump();

    final viewportBeforeToggle = canvasBuilder.viewports.last;
    final viewport = viewportBeforeToggle as CameraViewportState;
    expect(viewport.center!.coordinates.lng, 122);
    expect(viewport.center!.coordinates.lat, 12);
    await tester.tap(find.text('3D'));
    await tester.pump();

    expect(find.text('2D'), findsOneWidget);
    expect(canvasBuilder.viewports.last, same(viewportBeforeToggle));
  });
}

class _FakeMapboxMapCanvasBuilder implements MapboxMapCanvasBuilder {
  final List<ViewportState> viewports = [];

  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
  }) {
    viewports.add(viewport);
    return const SizedBox(key: Key('fake_mapbox_map'));
  }
}

class _FakeMapboxMapService implements MapboxMapService {
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
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {}
}

class _FakeReports implements CommunityReportsService {
  const _FakeReports(this.reports);
  final List<CommunityReport> reports;

  @override
  Future<List<CommunityReport>> load() async => reports;
}
