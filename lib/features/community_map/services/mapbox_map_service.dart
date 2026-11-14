import 'dart:convert';
import 'package:faunawatch/features/community_map/services/report_pin_image.dart';
import '../models/community_report.dart';

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
}

/// Mapbox implementation using the Standard style's light and 3D settings.
class MapboxCommunityMapService implements MapboxMapService {
  MapboxMap? _mapboxMap;
  static const _pinImage = 'community-report-logo-pin';

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
      await map.addImage(_pinImage, 2, await createReportPinImage());
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
        CameraOptions(),
        MbxEdgeInsets(top: 180, left: 48, bottom: 80, right: 48),
        12,
        null,
      );
      await map.setCamera(camera);
    }
  }

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {
    _mapboxMap = mapboxMap;
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
    await mapboxMap.setCamera(CameraOptions(pitch: is3dEnabled ? 55 : 0));
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
