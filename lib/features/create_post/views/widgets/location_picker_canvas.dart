import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Native map boundary, replaceable with a lightweight canvas in widget tests.
abstract interface class LocationPickerCanvasBuilder {
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
    required VoidCallback onError,
  });
}

class NativeLocationPickerCanvasBuilder implements LocationPickerCanvasBuilder {
  const NativeLocationPickerCanvasBuilder();
  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
    required VoidCallback onError,
  }) => MapWidget(
    styleUri: MapboxStyles.STANDARD,
    viewport: viewport,
    onMapCreated: onMapCreated,
    onStyleLoadedListener: onStyleLoaded,
    onMapLoadErrorListener: (_) => onError(),
  );
}

final locationPickerCanvasBuilderProvider =
    Provider<LocationPickerCanvasBuilder>(
      (ref) => const NativeLocationPickerCanvasBuilder(),
    );
