import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Encapsulates imperative Mapbox SDK configuration for the community map.
abstract interface class MapboxMapService {
  Future<void> attach(MapboxMap mapboxMap);

  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  });

  void detach();
}

/// Mapbox implementation using the Standard style's light and 3D settings.
class MapboxCommunityMapService implements MapboxMapService {
  MapboxMap? _mapboxMap;

  @override
  Future<void> attach(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
  }

  @override
  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  }) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    // Mapbox Standard is configured through its `basemap` style import.
    await mapboxMap.setStyleImportConfigProperty(
      'basemap',
      'lightPreset',
      brightness == Brightness.dark ? 'night' : 'day',
    );
    await mapboxMap.setStyleImportConfigProperty(
      'basemap',
      'show3dObjects',
      is3dEnabled,
    );
    await mapboxMap.setCamera(
      CameraOptions(pitch: is3dEnabled ? 55 : 0),
    );
  }

  @override
  void detach() {
    _mapboxMap = null;
  }
}

/// Provider for the Mapbox integration. Views interact only with the
/// CommunityMapViewModel, never with this service directly.
final mapboxMapServiceProvider = Provider<MapboxMapService>((ref) {
  return MapboxCommunityMapService();
});
