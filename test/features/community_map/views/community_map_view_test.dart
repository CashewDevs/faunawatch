import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';
import 'package:faunawatch/features/community_map/views/community_map_view.dart';
import 'package:faunawatch/features/community_map/views/widgets/mapbox_map_canvas.dart';

void main() {
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
}
