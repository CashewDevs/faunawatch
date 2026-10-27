// The SDK's controller constructor accepts this test-only platform contract.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_internal_member
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_maps_flutter_platform_interface/mapbox_maps_flutter_platform_interface_internal.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';

void main() {
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
      expect(platform.style.layers, hasLength(3));
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

  test('recreates demo layers after the style has been reloaded', () async {
    await service.showWarningDemo(DemoWarningLevel.approaching);
    platform.style.sources.clear();
    platform.style.layers.clear();
    await service.showWarningDemo(DemoWarningLevel.near);
    expect(platform.style.sources, hasLength(2));
    expect(platform.style.layers, hasLength(3));
  });
}

class _FakeMapPlatform implements MapboxMapPlatformInterface {
  @override
  final _FakeStyle style = _FakeStyle();
  final cameras = <CameraOptions>[];
  @override
  Future<void> setCamera(CameraOptions cameraOptions) async =>
      cameras.add(cameraOptions);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStyle implements StylePlatformInterface {
  final sources = <String>{};
  final layers = <String, Map<String, dynamic>>{};
  final data = <String, dynamic>{};

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
