// SDK controllers accept the test-only platform interface.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:mapbox_maps_flutter_platform_interface/mapbox_maps_flutter_platform_interface_internal.dart';
import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/create_post/services/location_search_service.dart';
import 'package:faunawatch/features/create_post/views/widgets/location_picker_canvas.dart';

const testPlace = PostLocation(
  latitude: 10.3,
  longitude: 123.9,
  label: 'Cebu City, Philippines',
);
const testPin = PostLocation(latitude: 10.4, longitude: 123.8);

class FakePlaceSearch implements LocationSearchService {
  List<PostLocation> results = [testPlace];
  int calls = 0;
  Object? error;
  Future<List<PostLocation>> Function(String)? handler;
  @override
  Future<List<PostLocation>> search(
    String query, {
    PostLocation? proximity,
  }) async {
    calls++;
    if (error != null) throw error!;
    return handler == null ? results : await handler!(query);
  }
}

class FakePickerMap implements LocationPickerMapService {
  void Function(PostLocation)? onTap;
  bool detached = false;
  final renders = <({PostLocation location, bool recenter})>[];
  final initialCameraLocations = <PostLocation?>[];
  final appearanceCalls = <bool>[];
  final focuses = <PostLocation>[];
  @override
  Future<void> initializeCamera(PostLocation? initialLocation) async {
    initialCameraLocations.add(initialLocation);
  }

  @override
  Future<void> applyAppearance({required bool isDarkMode}) async {
    appearanceCalls.add(isDarkMode);
  }

  @override
  Future<void> focus(PostLocation location) async {
    focuses.add(location);
  }

  @override
  void attach(MapboxMap map, {required void Function(PostLocation) onTap}) {
    this.onTap = onTap;
  }

  @override
  Future<void> showLocation(
    PostLocation location, {
    bool recenter = false,
  }) async {
    renders.add((location: location, recenter: recenter));
  }

  @override
  void detach() {
    detached = true;
    onTap = null;
  }
}

class FakePickerCanvas implements LocationPickerCanvasBuilder {
  FakePickerCanvas(this.map);
  final FakePickerMap map;
  CameraViewportState? initialViewport;
  bool _initialized = false;
  @override
  Widget build({
    required ViewportState viewport,
    required MapCreatedCallback onMapCreated,
    required OnStyleLoadedListener onStyleLoaded,
    required VoidCallback onError,
  }) {
    if (!_initialized) {
      initialViewport = viewport as CameraViewportState;
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMapCreated(MapboxMap(FakePickerPlatform()));
        onStyleLoaded(
          StyleLoadedEventData(
            timeInterval: EventTimeInterval(
              begin: DateTime(2026),
              end: DateTime(2026),
            ),
          ),
        );
      });
    }
    return Center(
      child: TextButton(
        onPressed: () => map.onTap?.call(testPin),
        child: const Text('Drop test pin'),
      ),
    );
  }
}

class FakePickerPlatform implements MapboxMapPlatformInterface {
  @override
  final StylePlatformInterface style = _FakePickerStyle();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePickerStyle implements StylePlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
