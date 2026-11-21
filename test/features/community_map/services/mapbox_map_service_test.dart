import 'dart:typed_data';

// The SDK's controller constructor accepts this test-only platform contract.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' show Brightness;
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_maps_flutter_platform_interface/mapbox_maps_flutter_platform_interface_internal.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeMapPlatform platform;
  late MapboxCommunityMapService service;
  setUp(() async {
    platform = _FakeMapPlatform();
    service = MapboxCommunityMapService();
    await service.attach(MapboxMap(platform));
  });

  test('registers only real report taps and removes them on detach', () {
    expect(platform.interactions.keys, ['community-report-tap']);
    service.detach();
    expect(platform.interactions, isEmpty);
  });

  test(
    'FaunaGuard draws live fixes, follows movement, preserves zoom and removes location on stop',
    () async {
      await service.showGuardLocation(null);
      expect(platform.style.sources, isEmpty);
      final fix = GuardLocation(
        latitude: 14.6,
        longitude: 121,
        accuracy: 8,
        timestamp: DateTime.now(),
      );
      await service.showGuardLocation(fix);
      expect(platform.cameras.last.zoom, 14);
      expect(platform.cameras.last.center!.coordinates.toJson(), [121.0, 14.6]);
      expect(platform.style.layers['fauna-guard-marker']!['type'], 'circle');
      await service.showGuardLocation(
        GuardLocation(
          latitude: 14.61,
          longitude: 121.01,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
      );
      expect(platform.cameras.last.zoom, isNull);
      expect(platform.cameras.last.center!.coordinates.toJson(), [
        121.01,
        14.61,
      ]);
      final cameras = platform.cameras.length;
      await service.showGuardLocation(null);
      expect(platform.style.data['fauna-guard-location']['features'], isEmpty);
      expect(platform.cameras.length, cameras);
      await service.showGuardLocation(fix);
      expect(platform.cameras.last.zoom, 14);
      service.detach();
      await service.showGuardLocation(fix);
      expect(platform.cameras.length, cameras + 1);
    },
  );

  test(
    'both maps use matching day and night lighting without picker camera changes',
    () async {
      final picker = MapboxLocationPickerMapService();
      picker.attach(MapboxMap(platform), onTap: (_) {});
      for (final brightness in [Brightness.dark, Brightness.light]) {
        await service.applyAppearance(
          brightness: brightness,
          is3dEnabled: true,
        );
        final communityPreset =
            platform.style.importSettings['basemap/lightPreset'];
        final camerasBefore = platform.cameras.length;
        await picker.applyAppearance(isDarkMode: brightness == Brightness.dark);
        expect(
          platform.style.importSettings['basemap/lightPreset'],
          communityPreset,
        );
        expect(
          communityPreset,
          brightness == Brightness.dark ? 'night' : 'day',
        );
        expect(platform.cameras.length, camerasBefore);
      }
    },
  );

  test('frames actual report coordinates only when requested', () async {
    const reports = [
      CommunityReport(
        id: 'r1',
        category: 'animal_in_need',
        latitude: 14.6,
        longitude: 121,
        description: 'Bird',
      ),
      CommunityReport(
        id: 'r2',
        category: 'animal_in_need',
        latitude: 10.3,
        longitude: 123.9,
        description: 'Turtle',
      ),
    ];
    await service.showReports(reports, recenter: true);
    expect(platform.fittedPoints.map((p) => p.coordinates.toJson()), [
      [121.0, 14.6],
      [123.9, 10.3],
    ]);
    expect(platform.maxZoom, 12);
    expect(platform.cameras, hasLength(1));
    expect(platform.fitOptions!.pitch, 55);
    expect(platform.cameras.single.pitch, 55);
    await service.showReports(reports);
    await service.showReports([], recenter: true);
    expect(platform.cameras, hasLength(1));
    service.detach();
    await service.showReports(reports, recenter: true);
    expect(platform.cameras, hasLength(1));
  });

  test(
    'FaunaGuard rings draw 1 km and 500 m fills under the pins and clear',
    () async {
      await service.showGuardRadius([]);
      expect(platform.style.sources, isEmpty);
      const reports = [
        CommunityReport(
          id: 'r1',
          category: 'animal_in_need',
          latitude: 14.6,
          longitude: 121,
          description: 'Bird',
        ),
        CommunityReport(
          id: 'r2',
          category: 'animal_in_need',
          latitude: 14.7,
          longitude: 121.1,
          description: 'Snake',
        ),
      ];
      await service.showGuardRadius(reports);
      for (final id in [
        'fauna-guard-radius-outer',
        'fauna-guard-radius-inner',
      ]) {
        final layer = platform.style.layers[id]!;
        expect(layer['type'], 'fill');
        expect(layer['slot'], 'middle');
      }
      // Redrawing reuses the sources and layers.
      await service.showGuardRadius(reports);
      for (final id in [
        'fauna-guard-radius-outer',
        'fauna-guard-radius-inner',
      ]) {
        final features = platform.style.data[id]['features'] as List;
        expect(features, hasLength(2));
        expect(features.first['geometry']['type'], 'Polygon');
      }
      await service.showGuardRadius([]);
      expect(platform.style.data['fauna-guard-radius-outer']['features'], []);
      expect(platform.style.data['fauna-guard-radius-inner']['features'], []);
    },
  );

  test('report fitting preserves an explicitly selected 2D view', () async {
    await service.applyAppearance(
      brightness: Brightness.light,
      is3dEnabled: false,
    );
    await service.showReports(const [
      CommunityReport(
        id: 'r1',
        category: 'animal_in_need',
        latitude: 14.6,
        longitude: 121,
        description: 'Bird',
      ),
    ], recenter: true);

    expect(platform.fitOptions!.pitch, 0);
    expect(platform.cameras.last.pitch, 0);
    expect(platform.style.importSettings['basemap/show3dObjects'], false);
  });

  test(
    'a slow report fit cannot override FaunaGuard following the user',
    () async {
      final fit = Completer<CameraOptions>();
      final fitting = Completer<void>();
      platform.fitOverride = () {
        fitting.complete();
        return fit.future;
      };
      final reports = service.showReports(const [
        CommunityReport(
          id: 'r1',
          category: 'animal_in_need',
          latitude: 10,
          longitude: 123,
          description: '',
        ),
      ], recenter: true);
      await fitting.future;
      await service.showGuardLocation(
        GuardLocation(
          latitude: 14.6,
          longitude: 121,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
      );
      final cameraCount = platform.cameras.length;
      fit.complete(
        CameraOptions(center: Point(coordinates: Position(123, 10)), zoom: 12),
      );
      await reports;
      expect(platform.cameras, hasLength(cameraCount));
      expect(platform.cameras.last.center!.coordinates.toJson(), [121.0, 14.6]);
    },
  );

  for (final initially3d in [true, false]) {
    test(
      'keeps the latest mode when toggled from ${initially3d ? '3D' : '2D'} during report fitting',
      () async {
        await service.applyAppearance(
          brightness: Brightness.light,
          is3dEnabled: initially3d,
        );
        final fitStarted = Completer<void>();
        final fittedCamera = Completer<CameraOptions>();
        platform.fitOverride = () {
          fitStarted.complete();
          return fittedCamera.future;
        };
        final showingReports = service.showReports(const [
          CommunityReport(
            id: 'r1',
            category: 'animal_in_need',
            latitude: 14.6,
            longitude: 121,
            description: 'Bird',
          ),
        ], recenter: true);
        await fitStarted.future;

        await service.applyAppearance(
          brightness: Brightness.light,
          is3dEnabled: !initially3d,
        );
        final center = Point(coordinates: Position(121, 14.6));
        fittedCamera.complete(
          CameraOptions(center: center, zoom: 12, pitch: initially3d ? 55 : 0),
        );
        await showingReports;

        expect(platform.cameras.last.pitch, initially3d ? 0 : 55);
        expect(platform.cameras.last.center, center);
        expect(platform.cameras.last.zoom, 12);
        expect(
          platform.style.importSettings['basemap/show3dObjects'],
          !initially3d,
        );
      },
    );
  }

  test(
    'draws approved report markers with RPC coordinates and replaces on refresh',
    () async {
      await service.showReports(const [
        CommunityReport(
          id: 'approved',
          category: 'animal_in_need',
          latitude: 10.12,
          longitude: 123.12,
          description: 'Bird',
        ),
      ]);
      final feature =
          (platform.style.data['community-reports']['features'] as List).single;
      expect(feature['properties']['postId'], 'approved');
      expect(feature['geometry']['coordinates'], [123.12, 10.12]);
      // Without a loaded photo the pin uses the shared logo picture.
      expect(feature['properties']['icon'], 'community-report-logo-pin');
      final layer = platform.style.layers['community-report-pins']!;
      expect(layer['type'], 'symbol');
      expect(layer['layout']['icon-image'], ['get', 'icon']);
      expect(layer['layout']['icon-anchor'], 'bottom');
      expect(layer['layout']['icon-allow-overlap'], isTrue);
      expect(layer['layout']['icon-ignore-placement'], isTrue);
      expect(platform.style.images, {'community-report-logo-pin'});
      expect(
        platform.style.renderedImages['community-report-logo-pin'],
        isA<StyleImageRgba>(),
      );
      expect(platform.style.imageScales['community-report-logo-pin'], 2);
      expect(platform.style.imageAddCount, 1);
      expect(
        platform
            .interactions['community-report-tap']!
            .featuresetDescriptor!
            .layerId,
        'community-report-pins',
      );
      await service.showReports([]);
      expect(platform.style.data['community-reports']['features'], isEmpty);
      expect(platform.style.layers, hasLength(1));
      expect(platform.style.imageAddCount, 1);
    },
  );

  test(
    'photo pins replace the logo per report and survive a refresh',
    () async {
      const reports = [
        CommunityReport(
          id: 'a',
          category: 'animal_in_need',
          latitude: 10.12,
          longitude: 123.12,
          description: 'Bird',
        ),
        CommunityReport(
          id: 'b',
          category: 'animal_in_need',
          latitude: 10.13,
          longitude: 123.13,
          description: 'Toad',
        ),
      ];
      Map<String, Object?> icons() => {
        for (final f in platform.style.data['community-reports']['features'])
          f['properties']['postId']: f['properties']['icon'],
      };
      await service.showReports(reports);
      final photo = StyleImage.rgba(
        width: 1,
        height: 1,
        pixels: Uint8List.fromList([0, 0, 0, 255]),
      );
      await service.showPinPhotos({'a': photo});
      expect(platform.style.images, contains('report-photo-a'));
      expect(platform.style.imageScales['report-photo-a'], 2);
      expect(icons(), {
        'a': 'report-photo-a',
        'b': 'community-report-logo-pin',
      });
      final added = platform.style.imageAddCount;
      await service.showPinPhotos({'a': photo});
      expect(platform.style.imageAddCount, added);

      await service.showReports(reports);
      expect(icons()['a'], 'report-photo-a');

      // A reloaded style lost the picture: back to the logo until re-shown.
      platform.style.images.remove('report-photo-a');
      await service.showReports(reports);
      expect(icons()['a'], 'community-report-logo-pin');
      await service.showPinPhotos({'a': photo});
      expect(icons()['a'], 'report-photo-a');
    },
  );

  test('recreates real report layers after style reload', () async {
    await service.showReports([]);
    platform.style.sources.clear();
    platform.style.layers.clear();
    platform.style.images.clear();
    await service.showReports([]);
    expect(platform.style.sources, {'community-reports'});
    expect(platform.style.layers.keys, ['community-report-pins']);
    expect(platform.style.images, {'community-report-logo-pin'});
    expect(platform.style.imageAddCount, 2);
  });

  test(
    'picker configures 3D and centers GPS without creating a report pin',
    () async {
      final picker = MapboxLocationPickerMapService();
      picker.attach(MapboxMap(platform), onTap: (_) {});
      await picker.initializeCamera(null);
      expect(platform.style.importSettings['basemap/show3dObjects'], true);
      expect(platform.cameras.single.pitch, 55);
      expect(platform.cameras.single.center!.coordinates.lng, 122);
      expect(platform.cameras.single.center!.coordinates.lat, 12);
      expect(platform.cameras.single.zoom, 5);
      await picker.focus(const PostLocation(latitude: 14.6, longitude: 121));
      expect(platform.cameras.last.center!.coordinates.lat, 14.6);
      expect(platform.cameras.last.center!.coordinates.lng, 121);
      expect(platform.cameras.last.pitch, 55);
      expect(platform.style.sources, isEmpty);
    },
  );

  test(
    'picker explicitly initializes existing and invalid opening locations',
    () async {
      final picker = MapboxLocationPickerMapService();
      picker.attach(MapboxMap(platform), onTap: (_) {});
      await picker.initializeCamera(
        const PostLocation(latitude: 10.3, longitude: 123.9),
      );
      expect(platform.cameras.single.center!.coordinates.lng, 123.9);
      expect(platform.cameras.single.center!.coordinates.lat, 10.3);
      expect(platform.cameras.single.zoom, 15);
      await picker.initializeCamera(
        const PostLocation(latitude: 91, longitude: 123),
      );
      expect(platform.cameras.last.center!.coordinates.lng, 122);
      expect(platform.cameras.last.center!.coordinates.lat, 12);
      expect(platform.cameras.last.zoom, 5);
      expect(platform.style.sources, isEmpty);
    },
  );

  test(
    'location picker uses the same blue logo pin as community reports',
    () async {
      await service.showReports([]);
      final picker = MapboxLocationPickerMapService();
      picker.attach(MapboxMap(platform), onTap: (_) {});
      await picker.showLocation(
        const PostLocation(latitude: 10.3, longitude: 123.9),
      );
      final reportPin =
          platform.style.renderedImages['community-report-logo-pin']!
              as StyleImageRgba;
      final pickerPin =
          platform.style.renderedImages['observation-location-pin']!
              as StyleImageRgba;
      expect(pickerPin.width, reportPin.width);
      expect(pickerPin.height, reportPin.height);
      expect(pickerPin.pixels, reportPin.pixels);
      expect(platform.style.imageScales['observation-location-pin'], 2);
      final layer = platform.style.layers['observation-location-pin']!;
      expect(layer['layout']['icon-anchor'], 'bottom');
      expect(layer['layout']['icon-ignore-placement'], isTrue);
      expect(layer['paint']['icon-emissive-strength'], 1);
    },
  );

  test(
    'location picker draws and moves a pin and detaches its tap handler',
    () async {
      final picker = MapboxLocationPickerMapService();
      picker.attach(MapboxMap(platform), onTap: (_) {});
      expect(
        platform.interactions.containsKey('pick-observation-location'),
        isTrue,
      );
      await picker.showLocation(
        const PostLocation(latitude: 10.3, longitude: 123.9),
        recenter: true,
      );
      expect(platform.style.sources, contains('observation-location'));
      expect(
        platform.style.layers['observation-location-pin']!['type'],
        'symbol',
      );
      expect(platform.cameras.single.center!.coordinates.lng, 123.9);
      expect(platform.cameras.single.center!.coordinates.lat, 10.3);
      expect(platform.cameras.single.pitch, 55);
      await picker.showLocation(
        const PostLocation(latitude: 10.4, longitude: 123.8),
      );
      final feature =
          (platform.style.data['observation-location']['features'] as List)
              .single;
      expect(feature['geometry']['coordinates'], [123.8, 10.4]);
      expect(platform.style.sources, hasLength(1));
      expect(platform.style.layers, hasLength(1));
      expect(platform.cameras, hasLength(1));
      expect(platform.style.imageAddCount, 1);
      picker.detach();
      expect(
        platform.interactions.containsKey('pick-observation-location'),
        isFalse,
      );
    },
  );
}

class _FakeMapPlatform implements MapboxMapPlatformInterface {
  @override
  final _FakeStyle style = _FakeStyle();
  final cameras = <CameraOptions>[];
  List<Point> fittedPoints = [];
  double? maxZoom;
  CameraOptions? fitOptions;
  Future<CameraOptions> Function()? fitOverride;
  @override
  Future<CameraOptions> cameraForCoordinatesPadding(
    List<Point> coordinates,
    CameraOptions camera,
    MbxEdgeInsets? coordinatesPadding,
    double? maxZoom,
    ScreenCoordinate? offset,
  ) async {
    fittedPoints = coordinates;
    this.maxZoom = maxZoom;
    fitOptions = camera;
    return fitOverride?.call() ??
        CameraOptions(center: coordinates.first, zoom: maxZoom, pitch: 0);
  }

  final interactions = <String, Interaction>{};
  @override
  void addInteraction<T extends TypedFeaturesetFeature<FeaturesetDescriptor>>(
    TypedInteraction<T> interaction, {
    String? interactionID,
  }) {
    interactions[interactionID!] = interaction;
  }

  @override
  void removeInteraction(String interactionID) =>
      interactions.remove(interactionID);

  @override
  Future<void> setCamera(CameraOptions cameraOptions) async =>
      cameras.add(cameraOptions);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStyle implements StylePlatformInterface {
  final importSettings = <String, Object>{};
  @override
  Future<void> setStyleImportConfigProperty(
    String importId,
    String config,
    Object value,
  ) async {
    importSettings['$importId/$config'] = value;
  }

  final sources = <String>{};
  final layers = <String, Map<String, dynamic>>{};
  final data = <String, dynamic>{};
  final images = <String>{};
  final renderedImages = <String, StyleImage>{};
  final imageScales = <String, double>{};
  int imageAddCount = 0;
  @override
  Future<bool> hasStyleImage(String imageId) async => images.contains(imageId);
  @override
  Future<void> addStyleImage(
    String imageId,
    double scale,
    StyleImage image,
    bool sdf,
    List<ImageStretches?> stretchX,
    List<ImageStretches?> stretchY,
    ImageContent? content,
  ) async {
    imageAddCount++;
    images.add(imageId);
    renderedImages[imageId] = image;
    imageScales[imageId] = scale;
  }

  @override
  Future<bool> styleSourceExists(String sourceId) async =>
      sources.contains(sourceId);
  @override
  Future<bool> styleLayerExists(String layerId) async =>
      layers.containsKey(layerId);
  @override
  Future<void> addStyleSource(String sourceId, String properties) async {
    expect(sources.add(sourceId), isTrue);
  }

  @override
  Future<void> setStyleSourceProperties(
    String sourceId,
    String properties,
  ) async {}
  @override
  Future<void> setStyleSourceProperty(
    String sourceId,
    String property,
    Object value,
  ) async {
    if (property == 'data') data[sourceId] = jsonDecode(value as String);
  }

  @override
  Future<void> addStyleLayer(
    String properties,
    LayerPosition? layerPosition,
  ) async {
    final layer = jsonDecode(properties) as Map<String, dynamic>;
    expect(layers.containsKey(layer['id']), isFalse);
    layers[layer['id'] as String] = layer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
