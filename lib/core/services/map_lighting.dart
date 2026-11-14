import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Keeps Mapbox Standard lighting consistent across all app maps.
Future<void> applyMapLighting(MapboxMap map, {required bool isDarkMode}) =>
    map.setStyleImportConfigProperty(
      'basemap',
      'lightPreset',
      isDarkMode ? 'night' : 'day',
    );
