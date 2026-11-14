// The SDK's controller constructor accepts this test-only platform contract.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
import 'dart:convert';
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
    expect(platform.cameras.single.pitch, isNull);
    await service.showReports(reports);
    await service.showReports([], recenter: true);
    expect(platform.cameras, hasLength(1));
    service.detach();
    await service.showReports(reports, recenter: true);
    expect(platform.cameras, hasLength(1));
  });

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
      final layer = platform.style.layers['community-report-pins']!;
      expect(layer['type'], 'symbol');
      expect(layer['layout']['icon-image'], 'community-report-logo-pin');
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
      await picker.configure3d();
      expect(platform.style.importSettings['basemap/show3dObjects'], true);
      expect(platform.cameras.single.pitch, 55);
      await picker.focus(const PostLocation(latitude: 14.6, longitude: 121));
      expect(platform.cameras.last.center!.coordinates.lat, 14.6);
      expect(platform.cameras.last.center!.coordinates.lng, 121);
      expect(platform.cameras.last.pitch, 55);
      expect(platform.style.sources, isEmpty);
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
    return CameraOptions(center: coordinates.first, zoom: maxZoom);
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
