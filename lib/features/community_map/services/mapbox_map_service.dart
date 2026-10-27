import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';

/// Encapsulates imperative Mapbox SDK configuration for the community map.
abstract interface class MapboxMapService {
  Future<void> attach(MapboxMap mapboxMap);

  Future<void> applyAppearance({
    required Brightness brightness,
    required bool is3dEnabled,
  });

  Future<void> showWarningDemo(DemoWarningLevel level, {bool recenter = false});

  void detach();
}

/// Mapbox implementation using the Standard style's light and 3D settings.
class MapboxCommunityMapService implements MapboxMapService {
  MapboxMap? _mapboxMap;

  static const _zonesSource = 'faunawatch-demo-zones';
  static const _pointsSource = 'faunawatch-demo-points';

  @override
  Future<void> showWarningDemo(
    DemoWarningLevel level, {
    bool recenter = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    const zoneColors = ['#FACC15', '#FB923C', '#EF4444'];
    final zones = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final zone in DemoWarningLevel.values)
          {
            'type': 'Feature',
            'properties': {
              'color': zoneColors[zone.index],
              'order': zone.index,
            },
            'geometry': {
              'type': 'Polygon',
              'coordinates': [WarningDemo.boundary(zone.radiusMeters)],
            },
          },
      ],
    });
    final points = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'color': '#EF4444',
            'label': 'Sample incident',
            'labelOffset': [0, -2.2],
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [WarningDemo.longitude, WarningDemo.latitude],
          },
        },
        {
          'type': 'Feature',
          'properties': {
            'color': '#2563EB',
            'label': 'Simulated position',
            'labelOffset': [0, 2.2],
          },
          'geometry': {
            'type': 'Point',
            'coordinates': WarningDemo.simulatedPosition(level),
          },
        },
      ],
    });
    if (!await map.styleSourceExists(_zonesSource)) {
      await map.addSource(GeoJsonSource(id: _zonesSource, data: zones));
    }
    if (!await map.styleLayerExists('faunawatch-demo-zones-fill')) {
      await map.addLayer(
        FillLayer(
          id: 'faunawatch-demo-zones-fill',
          sourceId: _zonesSource,
          slot: 'top',
          fillColorExpression: ['get', 'color'],
          fillOpacity: 0.2,
          fillOutlineColorExpression: ['get', 'color'],
          fillSortKeyExpression: ['get', 'order'],
        ),
      );
    }
    if (!await map.styleSourceExists(_pointsSource)) {
      await map.addSource(GeoJsonSource(id: _pointsSource, data: points));
    } else {
      await map.setStyleSourceProperty(_pointsSource, 'data', points);
    }
    if (!await map.styleLayerExists('faunawatch-demo-points')) {
      await map.addLayer(
        CircleLayer(
          id: 'faunawatch-demo-points',
          sourceId: _pointsSource,
          slot: 'top',
          circleColorExpression: ['get', 'color'],
          circleRadius: 6,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2,
          circleEmissiveStrength: 1,
        ),
      );
    }
    if (!await map.styleLayerExists('faunawatch-demo-labels')) {
      await map.addLayer(
        SymbolLayer(
          id: 'faunawatch-demo-labels',
          sourceId: _pointsSource,
          slot: 'top',
          textFieldExpression: ['get', 'label'],
          textSize: 12,
          textOffsetExpression: ['get', 'labelOffset'],
          textAllowOverlap: true,
          textColor: 0xFF111827,
          textHaloColor: 0xFFFFFFFF,
          textHaloWidth: 2,
        ),
      );
    }
    if (recenter) {
      await map.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(WarningDemo.longitude, WarningDemo.latitude),
          ),
          zoom: WarningDemo.zoom,
        ),
      );
    }
  }

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
    await mapboxMap.setCamera(CameraOptions(pitch: is3dEnabled ? 55 : 0));
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
