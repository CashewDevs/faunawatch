import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// UI boundary for Mapbox's native platform map widget.
///
/// Keeping this behind an interface allows widget tests to use a lightweight
/// canvas without trying to register a native platform view.
abstract interface class MapboxMapCanvasBuilder {
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
  });
}

class DefaultMapboxMapCanvasBuilder implements MapboxMapCanvasBuilder {
  const DefaultMapboxMapCanvasBuilder();

  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
  }) {
    return MapWidget(
      styleUri: MapboxStyles.STANDARD,
      viewport: viewport,
      onMapCreated: onMapCreated,
      onStyleLoadedListener: onStyleLoaded,
    );
  }
}

final mapboxMapCanvasBuilderProvider = Provider<MapboxMapCanvasBuilder>((ref) {
  return const DefaultMapboxMapCanvasBuilder();
});
