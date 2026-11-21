import 'dart:convert';
import 'package:faunawatch/core/services/map_lighting.dart';
import 'package:faunawatch/core/services/map_pin_image.dart';
import '../models/community_report.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_proximity.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_radius.dart';

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

  /// Draws FaunaGuard's 1 km and 500 m warning rings around [reports];
  /// an empty list removes them.
  Future<void> showGuardRadius(List<CommunityReport> reports);

  /// Moves the camera to [focus] (unless [moveCamera] is false) and draws the
  /// owner-only marker when [MapFocus.showsOwnerMarker]. Null removes it.
  Future<void> showFocus(MapFocus? focus, {bool moveCamera = true});

  /// The map area currently on screen, or null when the map is not ready.
  Future<MapBounds?> visibleBounds();

  /// Gives each report in [photos] (report id to pin picture) its own pin;
  /// the others keep the logo pin.
  Future<void> showPinPhotos(Map<String, StyleImage> photos);
}

/// A map area in degrees.
typedef MapBounds = ({double south, double west, double north, double east});

/// Mapbox implementation using the Standard style's light and 3D settings.
class MapboxCommunityMapService implements MapboxMapService {
  MapboxMap? _mapboxMap;
  double _pitch = 55;
  static const _pinImage = 'community-report-logo-pin';
  static const _reportsSource = 'community-reports';
  bool _guardHasCentered = false;

  /// The reports last drawn, to redraw them when pin pictures arrive.
  List<CommunityReport> _reports = const [];

  /// Reports whose own photo pin was added to the current style.
  final _photoIds = <String>{};

  static String _photoImage(String reportId) => 'report-photo-$reportId';

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
  Future<void> showFocus(MapFocus? focus, {bool moveCamera = true}) async {
    final map = _mapboxMap;
    if (map == null) return;
    const source = 'own-post-location';
    final private = focus != null && focus.showsOwnerMarker;
    final exists = await map.styleSourceExists(source);
    if (private || exists) {
      final data = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          if (private)
            {
              'type': 'Feature',
              'properties': <String, Object>{},
              'geometry': {
                'type': 'Point',
                'coordinates': [focus.longitude, focus.latitude],
              },
            },
        ],
      });
      if (exists) {
        await map.setStyleSourceProperty(source, 'data', data);
      } else {
        await map.addSource(GeoJsonSource(id: source, data: data));
      }
      if (!await map.styleLayerExists('own-post-marker')) {
        await map.addLayer(
          CircleLayer(
            id: 'own-post-marker',
            sourceId: source,
            slot: 'top',
            circleRadius: 11,
            circleColor: const Color(0xFFF57C00).toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 3,
            circleEmissiveStrength: 1,
          ),
        );
      }
    }
    if (focus == null || !moveCamera || _mapboxMap != map) return;
    await map.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(focus.longitude, focus.latitude)),
        zoom: 14,
        pitch: _pitch,
      ),
    );
  }

  @override
  Future<void> showGuardRadius(List<CommunityReport> reports) async {
    final map = _mapboxMap;
    if (map == null) return;
    final rings = guardRadiusRings(reports);
    // Outer (1 km) is drawn first so the inner (500 m) ring sits on top.
    for (final (proximity, source, color) in const [
      (GuardProximity.gettingCloser, 'fauna-guard-radius-outer', 0xFFFFA000),
      (GuardProximity.nearby, 'fauna-guard-radius-inner', 0xFFE53935),
    ]) {
      final exists = await map.styleSourceExists(source);
      if (rings.isEmpty && !exists) continue;
      final data = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          for (final ring in rings)
            if (ring.proximity == proximity)
              {
                'type': 'Feature',
                'properties': <String, Object>{},
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [ring.points],
                },
              },
        ],
      });
      if (exists) {
        await map.setStyleSourceProperty(source, 'data', data);
      } else {
        await map.addSource(GeoJsonSource(id: source, data: data));
      }
      if (!await map.styleLayerExists(source)) {
        await map.addLayer(
          FillLayer(
            id: source,
            sourceId: source,
            // Under road names and the report pins, above the ground.
            slot: 'middle',
            fillColor: color,
            fillOpacity: 0.18,
            fillOutlineColor: color,
            fillEmissiveStrength: 1,
          ),
        );
      }
    }
  }

  @override
  Future<void> showReports(
    List<CommunityReport> reports, {
    bool recenter = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    _reports = List.of(reports);
    // A reloaded style loses its images; those pins fall back to the logo
    // until their pictures are shown again.
    for (final id in _photoIds.toList()) {
      if (!await map.hasStyleImage(_photoImage(id))) _photoIds.remove(id);
    }
    await _setReportsData(map);
    if (!await map.hasStyleImage(_pinImage)) {
      await map.addImage(_pinImage, 2, await createMapPinImage());
    }
    if (!await map.styleLayerExists('community-report-pins')) {
      await map.addLayer(
        SymbolLayer(
          id: 'community-report-pins',
          sourceId: _reportsSource,
          slot: 'top',
          // Each feature names its pin picture (its photo or the logo).
          iconImageExpression: ['get', 'icon'],
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

  Future<void> _setReportsData(MapboxMap map) async {
    final data = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final report in _reports)
          {
            'type': 'Feature',
            'properties': {
              'postId': report.id,
              'icon': _photoIds.contains(report.id)
                  ? _photoImage(report.id)
                  : _pinImage,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [report.longitude, report.latitude],
            },
          },
      ],
    });
    if (await map.styleSourceExists(_reportsSource)) {
      await map.setStyleSourceProperty(_reportsSource, 'data', data);
    } else {
      await map.addSource(GeoJsonSource(id: _reportsSource, data: data));
    }
  }

  @override
  Future<MapBounds?> visibleBounds() async {
    final map = _mapboxMap;
    if (map == null) return null;
    final camera = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      camera.toCameraOptions(),
    );
    final sw = bounds.southwest.coordinates, ne = bounds.northeast.coordinates;
    return (
      south: sw.lat.toDouble(),
      west: sw.lng.toDouble(),
      north: ne.lat.toDouble(),
      east: ne.lng.toDouble(),
    );
  }

  @override
  Future<void> showPinPhotos(Map<String, StyleImage> photos) async {
    final map = _mapboxMap;
    if (map == null || photos.isEmpty) return;
    var changed = false;
    for (final MapEntry(key: id, value: image) in photos.entries) {
      final name = _photoImage(id);
      if (!await map.hasStyleImage(name)) {
        await map.addImage(name, 2, image);
      }
      changed = _photoIds.add(id) || changed;
    }
    if (_mapboxMap != map) return;
    if (changed && _reports.isNotEmpty) await _setReportsData(map);
  }

  @override
  Future<void> attach(
    MapboxMap mapboxMap, {
    void Function(String)? onPostTap,
  }) async {
    _mapboxMap = mapboxMap;
    _guardHasCentered = false;
    _photoIds.clear();
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
