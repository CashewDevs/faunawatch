import 'dart:convert';
import 'package:faunawatch/core/services/map_lighting.dart';
import 'package:faunawatch/core/services/map_pin_image.dart';
import '../models/community_report.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Encapsulates imperative Mapbox SDK configuration for the community map.
abstract interface class MapboxMapService {
  Future<void> attach(MapboxMap mapboxMap, {void Function(String)? onPostTap});

  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  });

  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  });

  void detach();

  Future<void> showGuardLocation(GuardLocation? location);
}

/// Mapbox implementation using the Standard style's light and 3D settings.
class MapboxCommunityMapService implements MapboxMapService {
  MapboxMap? _mapboxMap;
  double _pitch = 55;
  static const _pinImage = 'community-report-logo-pin';
  bool _guardHasCentered = false;

  @override
  Future<void> showGuardLocation(GuardLocation? location) async {
    final map = _mapboxMap;
    if (map == null) return;
    const source = 'fauna-guard-location';
    final exists = await map.styleSourceExists(source);
    if (location == null && !exists) {
      _guardHasCentered = false;
      return;
    }
    final data = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        if (location != null)
          {
            'type': 'Feature',
            'properties': <String, Object>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [location.longitude, location.latitude],
            },
          },
      ],
    });
    if (exists) {
      await map.setStyleSourceProperty(source, 'data', data);
    } else {
      await map.addSource(GeoJsonSource(id: source, data: data));
    }
    if (!await map.styleLayerExists('fauna-guard-marker')) {
      await map.addLayer(
        CircleLayer(
          id: 'fauna-guard-marker',
          sourceId: source,
          slot: 'top',
          circleRadius: 9,
          circleColor: const Color(0xFF1976D2).toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
          circleEmissiveStrength: 1,
        ),
      );
    }
    if (_mapboxMap != map) return;
    if (location == null) {
      _guardHasCentered = false;
    } else {
      await map.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          zoom: _guardHasCentered ? null : 14,
          pitch: _pitch,
        ),
      );
      _guardHasCentered = true;
    }
  }

  @override
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    const source = 'community-reports';
    final data = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final report in reports)
          {
            'type': 'Feature',
            'properties': {'postId': report.id},
            'geometry': {
              'type': 'Point',
              'coordinates': [report.longitude, report.latitude],
            },
          },
      ],
    });
    if (await map.styleSourceExists(source)) {
      await map.setStyleSourceProperty(source, 'data', data);
    } else {
      await map.addSource(GeoJsonSource(id: source, data: data));
    }
    if (!await map.hasStyleImage(_pinImage)) {
      await map.addImage(_pinImage, 2, await createMapPinImage());
    }
    if (!await map.styleLayerExists('community-report-pins')) {
      await map.addLayer(
        SymbolLayer(
          id: 'community-report-pins',
          sourceId: source,
          slot: 'top',
          iconImage: _pinImage,
          iconAnchor: IconAnchor.BOTTOM,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconEmissiveStrength: 1,
        ),
      );
    }
    if (recenter && reports.isNotEmpty) {
      final camera = await map.cameraForCoordinatesPadding(
        [
          for (final report in reports)
            Point(coordinates: Position(report.longitude, report.latitude)),
        ],
        CameraOptions(pitch: _pitch),
        MbxEdgeInsets(top: 180, left: 48, bottom: 80, right: 48),
        12,
        null,
      );
      // Keep the selected mode even if it changed while fitting the reports.
      camera.pitch = _pitch;
      // A GPS fix may have taken over the camera while the fit was pending.
      if (_mapboxMap != map || _guardHasCentered) return;
      await map.setCamera(camera);
    }
  }

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {
    _mapboxMap = mapboxMap;
    _guardHasCentered = false;
    mapboxMap.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: 'community-report-pins'), (
        feature,
        context,
      ) {
        final id = feature.properties['postId'];
        if (id is String) onPostTap?.call(id);
      }, radius: 12),
      interactionID: 'community-report-tap',
    );
  }

  @override
  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  }) async {
    _pitch = is3dEnabled ? 55 : 0;
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    // Mapbox Standard is configured through its `basemap` style import.
    await applyMapLighting(
      mapboxMap,
      isDarkMode: brightness == Brightness.dark,
    );
    await mapboxMap.setStyleImportConfigProperty(
      'basemap',
      'show3dObjects',
      is3dEnabled,
    );
    await mapboxMap.setCamera(CameraOptions(pitch: _pitch));
  }

  @override
  void detach() {
    _mapboxMap?.removeInteraction('community-report-tap');
    _mapboxMap = null;
  }
}

/// Provider for the Mapbox integration. Views interact only with the
/// CommunityMapViewModel, never with this service directly.
final mapboxMapServiceProvider = Provider<MapboxMapService>((ref) {
  return MapboxCommunityMapService();
});
