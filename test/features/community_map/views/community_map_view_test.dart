import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_guide_sheet.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_purpose_card.dart';
import 'package:faunawatch/features/community_map/views/widgets/map_warning_demo_card.dart';

void main() {
  Widget buildMap({ThemeData? theme, double textScale = 1}) {
    return ProviderScope(
      overrides: [
        mapboxMapCanvasBuilderProvider.overrideWithValue(
          _FakeMapboxMapCanvasBuilder(),
        ),
        mapboxMapServiceProvider.overrideWithValue(_FakeMapboxMapService()),
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

  testWidgets('explains the map purpose and identifies planned features', (
    tester,
  ) async {
    await tester.pumpWidget(buildMap());
    await tester.pump();
    expect(find.byType(MapPurposeCard), findsOneWidget);
    expect(find.text('Wildlife encounters, on one shared map'), findsOneWidget);
    expect(
      find.textContaining('Try the Cebu City warning demo'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('How this map works'));
    await tester.tap(find.text('How this map works'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsOneWidget);
    expect(find.text('Find reported encounters'), findsOneWidget);
    expect(find.textContaining('approximate'), findsOneWidget);
    expect(
      find.textContaining('AI assessments are preliminary'),
      findsOneWidget,
    );
    expect(find.textContaining('Danger Zone'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Close map guide'));
    await tester.pumpAndSettle();
    expect(find.byType(MapGuideSheet), findsNothing);
    expect(find.byKey(const Key('fake_mapbox_map')), findsOneWidget);
    await tester.tap(find.text('3D'));
    await tester.pump();
    expect(find.text('2D'), findsOneWidget);
  });

  testWidgets(
    'X dismisses preview, demo levels change, controls and preview reopen',
    (tester) async {
      await tester.pumpWidget(buildMap());
      await tester.pump();
      await tester.tap(find.byTooltip('Dismiss map preview'));
      await tester.pump();
      expect(find.byType(MapPurposeCard), findsNothing);
      expect(find.byType(MapWarningDemoCard), findsOneWidget);
      expect(find.textContaining('750 m away (simulated)'), findsOneWidget);
      await tester.ensureVisible(find.text('Near'));
      await tester.tap(find.text('Near'));
      await tester.pump();
      expect(find.textContaining('350 m away (simulated)'), findsOneWidget);
      await tester.tap(find.text('Danger Zone'));
      await tester.pump();
      expect(find.textContaining('150 m away (simulated)'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Collapse warning demo'));
      await tester.tap(find.byTooltip('Collapse warning demo'));
      await tester.pump();
      expect(find.byType(MapWarningDemoCard), findsNothing);
      await tester.tap(find.text('Warning demo · Danger Zone'));
      await tester.pump();
      expect(find.byType(MapWarningDemoCard), findsOneWidget);
      await tester.tap(find.byTooltip('Show map preview'));
      await tester.pump();
      expect(find.byType(MapPurposeCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      await tester.tap(find.byTooltip('Dismiss map preview'));
      await tester.pump();
      await tester.ensureVisible(find.text('Danger Zone'));
      await tester.tap(find.text('Danger Zone'));
      await tester.pump();
      expect(find.textContaining('150 m away (simulated)'), findsOneWidget);
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
    expect(viewport.center!.coordinates.lng, WarningDemo.longitude);
    expect(viewport.center!.coordinates.lat, WarningDemo.latitude);
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
  Future<void> attach(MapboxMap mapboxMap) async {}

  @override
  void detach() {}

  @override
  Future<void> showWarningDemo(
    DemoWarningLevel level, {
    bool recenter = false,
  }) async {}
}
