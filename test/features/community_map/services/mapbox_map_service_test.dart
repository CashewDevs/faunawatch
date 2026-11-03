// The SDK's controller constructor accepts this test-only platform contract.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
import 'dart:convert';
import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_maps_flutter_platform_interface/mapbox_maps_flutter_platform_interface_internal.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
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

  test(
    'draws all zones and two labeled demo markers without duplicating layers',
    () async {
      await service.showWarningDemo(DemoWarningLevel.approaching);
      expect(platform.style.sources, hasLength(2));
      expect(platform.style.layers.values.map((layer) => layer['type']), [
        'fill',
        'circle',
        'symbol',
        'symbol',
      ]);
      final zones =
          platform.style.data['faunawatch-demo-zones']['features'] as List;
      expect(zones, hasLength(3));
      expect(zones.map((zone) => zone['properties']['color']), [
        '#FACC15',
        '#FB923C',
        '#EF4444',
      ]);
      final points =
          platform.style.data['faunawatch-demo-points']['features'] as List;
      expect(points.map((point) => point['properties']['label']), [
        'Sample incident',
        'Simulated position',
      ]);
      final originalPosition = points.last['geometry']['coordinates'];
      await service.showWarningDemo(DemoWarningLevel.danger);
      expect(platform.style.sources, hasLength(2));
      expect(platform.style.layers, hasLength(4));
      final updated =
          platform.style.data['faunawatch-demo-points']['features'] as List;
      expect(
        updated.last['geometry']['coordinates'],
        WarningDemo.simulatedPosition(DemoWarningLevel.danger),
      );
      expect(updated.last['geometry']['coordinates'], isNot(originalPosition));
      expect(platform.cameras, isEmpty);
    },
  );

  test('registers only the post pin and removes its tap handler on detach', () {
    expect(
      platform.interactions['sample-post-tap']!.featuresetDescriptor!.layerId,
      'faunawatch-demo-post-pin',
    );
    service.detach();
    expect(platform.interactions, isEmpty);
  });

  test('explicit recenter returns to Cebu and detach stops drawing', () async {
    await service.showWarningDemo(DemoWarningLevel.near, recenter: true);
    final camera = platform.cameras.single;
    expect(camera.center!.coordinates.lng, WarningDemo.longitude);
    expect(camera.center!.coordinates.lat, WarningDemo.latitude);
    expect(camera.zoom, WarningDemo.zoom);
    expect(camera.pitch, isNull); // Preserve the chosen 2D/3D mode.
    service.detach();
    await service.showWarningDemo(DemoWarningLevel.danger, recenter: true);
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
    },
  );

  test('recreates demo layers after the style has been reloaded', () async {
    await service.showWarningDemo(DemoWarningLevel.approaching);
    platform.style.sources.clear();
    platform.style.layers.clear();
    await service.showWarningDemo(DemoWarningLevel.near);
    expect(platform.style.sources, hasLength(2));
    expect(platform.style.layers, hasLength(4));
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
    images.add(imageId);
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
