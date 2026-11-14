import 'dart:convert';
import 'package:faunawatch/core/services/map_pin_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/post_location.dart';

abstract interface class LocationPickerMapService {
  void attach(MapboxMap map, {required void Function(PostLocation) onTap});
  Future<void> configure3d();
  Future<void> focus(PostLocation location);
  Future<void> showLocation(PostLocation location, {bool recenter = false});
  void detach();
}

class MapboxLocationPickerMapService implements LocationPickerMapService {
  MapboxMap? _map;
  static const _source = 'observation-location';
  static const _pin = 'observation-location-pin';

  @override
  Future<void> configure3d() async {
    final map = _map;
    if (map == null) return;
    await map.setStyleImportConfigProperty('basemap', 'show3dObjects', true);
    await map.setCamera(CameraOptions(pitch: 55));
  }

  @override
  Future<void> focus(PostLocation location) async {
    if (!location.isValid) return;
    await _map?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        zoom: 15,
        pitch: 55,
      ),
    );
  }

  @override
  void attach(MapboxMap map, {required void Function(PostLocation) onTap}) {
    _map = map;
    map.addInteraction(
      TapInteraction.onMap((context) {
        onTap(
          PostLocation(
            latitude: context.point.coordinates.lat.toDouble(),
            longitude: context.point.coordinates.lng.toDouble(),
          ),
        );
      }),
      interactionID: 'pick-observation-location',
    );
  }

  @override
  Future<void> showLocation(
    PostLocation location, {
    bool recenter = false,
  }) async {
    final map = _map;
    if (map == null || !location.isValid) return;
    final data = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [location.longitude, location.latitude],
          },
        },
      ],
    });
    if (!await map.styleSourceExists(_source)) {
      await map.addSource(GeoJsonSource(id: _source, data: data));
    } else {
      await map.setStyleSourceProperty(_source, 'data', data);
    }
    if (!await map.hasStyleImage(_pin)) {
      await map.addImage(_pin, 2, await createMapPinImage());
    }
    if (!await map.styleLayerExists(_pin)) {
      await map.addLayer(
        SymbolLayer(
          id: _pin,
          sourceId: _source,
          slot: 'top',
          iconImage: _pin,
          iconAnchor: IconAnchor.BOTTOM,
          iconAllowOverlap: true,
        ),
      );
    }
    if (recenter) {
      await focus(location);
    }
  }

  @override
  void detach() {
    _map?.removeInteraction('pick-observation-location');
    _map = null;
  }
}

final locationPickerMapServiceProvider =
    Provider.autoDispose<LocationPickerMapService>(
      (ref) => MapboxLocationPickerMapService(),
    );
