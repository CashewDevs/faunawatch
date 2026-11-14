// The SDK controller constructor accepts this test-only platform contract.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/create_post/models/post_location.dart';
import 'package:faunawatch/features/create_post/services/location_picker_map_service.dart';
import 'package:faunawatch/features/create_post/services/location_search_service.dart';
import 'package:faunawatch/features/create_post/viewmodels/location_picker_viewmodel.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'location_picker_fakes.dart';
import 'create_post_viewmodel_test.dart' show FakeLocations;

class _PendingLocations implements PhotoLocationService {
  const _PendingLocations(this.pending);
  final Future<GeoCoordinates?> pending;
  @override
  Future<GeoCoordinates?> currentLocation() => pending;
  @override
  Future<GeoCoordinates?> locationInPhoto(String path) async => null;
}

void main() {
  late ProviderContainer container;
  late FakePlaceSearch search;
  late FakePickerMap map;
  late FakeLocations locations;
  final provider = locationPickerViewModelProvider(null);
  setUp(() {
    search = FakePlaceSearch();
    map = FakePickerMap();
    locations = FakeLocations();
    container = ProviderContainer(
      overrides: [
        locationSearchServiceProvider.overrideWithValue(search),
        locationPickerMapServiceProvider.overrideWithValue(map),
        photoLocationServiceProvider.overrideWithValue(locations),
      ],
    );
    container.listen(provider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test(
    'applies the active theme once ready and reapplies it on style reload',
    () async {
      final vm = container.read(provider.notifier);
      await vm.setDarkMode(true);
      expect(map.appearanceCalls, isEmpty);
      vm.onMapCreated(MapboxMap(FakePickerPlatform()));
      await vm.onStyleLoaded();
      expect(map.appearanceCalls, [true]);
      await vm.onStyleLoaded();
      expect(map.appearanceCalls, [true, true]);
      await vm.setDarkMode(true);
      expect(map.appearanceCalls, [true, true]);
      expect(container.read(provider).isDarkMode, isTrue);
    },
  );

  test('theme changes preserve the pin, camera and GPS warning', () async {
    final vm = container.read(provider.notifier);
    vm.onMapCreated(MapboxMap(FakePickerPlatform()));
    await vm.onStyleLoaded();
    vm.selectPin(testPin);
    await pumpEventQueue();
    await vm.locate();
    final warning = container.read(provider).error;
    expect(warning, isNotNull);
    await vm.setDarkMode(true);
    await vm.setDarkMode(false);
    expect(map.appearanceCalls, [false, true, false]);
    expect(map.initialCameraLocations, [null]);
    expect(map.focuses, isEmpty);
    expect(map.renders.last.recenter, isFalse);
    expect(vm.confirm(), testPin);
    expect(container.read(provider).error, warning);
  });

  test(
    'startup GPS centers the 3D map without choosing an observation pin',
    () async {
      locations.location = const GeoCoordinates(latitude: 14.6, longitude: 121);
      final vm = container.read(provider.notifier);
      await vm.initialize();
      expect(map.focuses, isEmpty);
      vm.onMapCreated(MapboxMap(FakePickerPlatform()));
      await vm.onStyleLoaded();
      expect(map.initialCameraLocations, [null]);
      expect(map.focuses.single.latitude, 14.6);
      expect(map.focuses.single.longitude, 121);
      expect(vm.confirm(), isNull);
      await vm.initialize();
      expect(map.focuses, hasLength(1));
    },
  );

  test('startup GPS preserves an existing observation pin', () async {
    locations.location = const GeoCoordinates(latitude: 14.6, longitude: 121);
    final initial = locationPickerViewModelProvider(testPlace);
    container.listen(initial, (_, _) {});
    final vm = container.read(initial.notifier);
    vm.onMapCreated(MapboxMap(FakePickerPlatform()));
    await vm.onStyleLoaded();
    await vm.initialize();
    expect(map.focuses.single.latitude, 14.6);
    expect(vm.confirm(), testPlace);
  });

  test('unavailable startup GPS leaves search and pinning usable', () async {
    final vm = container.read(provider.notifier);
    vm.onMapCreated(MapboxMap(FakePickerPlatform()));
    await vm.onStyleLoaded();
    await vm.initialize();
    expect(map.initialCameraLocations, [null]);
    expect(map.focuses, isEmpty);
    expect(container.read(provider).isLocating, isFalse);
    expect(container.read(provider).error, contains('tap the map'));
    vm.selectPin(testPin);
    expect(vm.confirm(), testPin);
  });

  for (final throws in [false, true]) {
    test(
      'map camera initializes before GPS ${throws ? 'throws' : 'returns no location'}',
      () async {
        final pending = Completer<GeoCoordinates?>();
        final local = ProviderContainer(
          overrides: [
            locationSearchServiceProvider.overrideWithValue(search),
            locationPickerMapServiceProvider.overrideWithValue(map),
            photoLocationServiceProvider.overrideWithValue(
              _PendingLocations(pending.future),
            ),
          ],
        );
        addTearDown(local.dispose);
        local.listen(provider, (_, _) {});
        final vm = local.read(provider.notifier);
        final startup = vm.initialize();
        // Both native callback orders must configure the map without waiting for GPS.
        await vm.onStyleLoaded();
        expect(map.initialCameraLocations, isEmpty);
        vm.onMapCreated(MapboxMap(FakePickerPlatform()));
        await pumpEventQueue();
        expect(map.initialCameraLocations, [null]);
        expect(local.read(provider).isLocating, isTrue);
        expect(vm.confirm(), isNull);
        if (throws) {
          pending.completeError(StateError('location unavailable'));
        } else {
          pending.complete(null);
        }
        await startup;
        expect(local.read(provider).isLocating, isFalse);
        expect(local.read(provider).mapHasError, isFalse);
        expect(map.initialCameraLocations, [null]);
        vm.updateQuery('Cebu');
        await vm.search();
        vm.selectResult(testPlace);
        await pumpEventQueue();
        expect(map.renders.last.location, testPlace);
        expect(map.renders.last.recenter, isTrue);
        map.onTap!(testPin);
        await pumpEventQueue();
        expect(vm.confirm(), testPin);
        expect(map.renders.last.location, testPin);
      },
    );
  }

  test(
    'GPS denial opens on the existing pin without selecting the fallback',
    () async {
      final initial = locationPickerViewModelProvider(testPlace);
      container.listen(initial, (_, _) {});
      final vm = container.read(initial.notifier);
      await vm.initialize();
      vm.onMapCreated(MapboxMap(FakePickerPlatform()));
      await vm.onStyleLoaded();
      expect(map.initialCameraLocations, [testPlace]);
      expect(map.focuses, isEmpty);
      expect(map.renders.last.location, testPlace);
      expect(vm.confirm(), testPlace);
    },
  );

  test('late startup GPS cannot replace a user-selected location', () async {
    final pending = Completer<GeoCoordinates?>();
    final local = ProviderContainer(
      overrides: [
        locationSearchServiceProvider.overrideWithValue(search),
        locationPickerMapServiceProvider.overrideWithValue(map),
        photoLocationServiceProvider.overrideWithValue(
          _PendingLocations(pending.future),
        ),
      ],
    );
    addTearDown(local.dispose);
    local.listen(provider, (_, _) {});
    final vm = local.read(provider.notifier);
    vm.onMapCreated(MapboxMap(FakePickerPlatform()));
    await vm.onStyleLoaded();
    final startup = vm.initialize();
    vm.selectPin(testPin);
    pending.complete(const GeoCoordinates(latitude: 14.6, longitude: 121));
    await startup;
    expect(vm.confirm(), testPin);
    expect(map.focuses, isEmpty);
  });

  test('no default pin can be confirmed; invalid coordinates are rejected', () {
    final vm = container.read(provider.notifier);
    expect(vm.confirm(), isNull);
    vm.selectPin(const PostLocation(latitude: 91, longitude: 1));
    expect(vm.confirm(), isNull);
    vm.selectPin(testPin);
    expect(vm.confirm(), testPin);
  });

  test(
    'search runs only when requested and selecting result waits for map readiness',
    () async {
      final vm = container.read(provider.notifier);
      vm.updateQuery('Cebu');
      expect(search.calls, 0);
      await vm.search();
      expect(container.read(provider).results, [testPlace]);
      expect(vm.confirm(), isNull);
      vm.selectResult(testPlace);
      expect(vm.confirm(), testPlace);
      expect(map.renders, isEmpty);
      vm.onMapCreated(MapboxMap(FakePickerPlatform()));
      await vm.onStyleLoaded();
      expect(map.renders.last.location, testPlace);
      expect(map.renders.any((render) => render.recenter), isTrue);
      map.onTap!(testPin);
      await Future<void>.delayed(Duration.zero);
      expect(vm.confirm(), testPin);
      expect(map.renders.last.recenter, isFalse);
    },
  );

  test(
    'search result recenters the loaded map and clears result list',
    () async {
      final vm = container.read(provider.notifier);
      vm.onMapCreated(MapboxMap(FakePickerPlatform()));
      await vm.onStyleLoaded();
      vm.selectResult(testPlace);
      await Future<void>.delayed(Duration.zero);
      expect(map.renders.single.recenter, isTrue);
      expect(container.read(provider).results, isEmpty);
    },
  );

  test(
    'typing a new query and pinning invalidate stale search results',
    () async {
      final vm = container.read(provider.notifier);
      final pending = Completer<List<PostLocation>>();
      search.handler = (_) => pending.future;
      vm.updateQuery('Old search');
      final request = vm.search();
      vm.updateQuery('New search');
      vm.selectPin(testPin);
      pending.complete([testPlace]);
      await request;
      expect(container.read(provider).query, 'New search');
      expect(container.read(provider).results, isEmpty);
      expect(vm.confirm(), testPin);
    },
  );

  test(
    'failed search preserves selected pin and hides raw HTTP errors',
    () async {
      final vm = container.read(provider.notifier);
      vm.selectPin(testPin);
      vm.updateQuery('Cebu');
      search.error = StateError('private-request-details');
      await vm.search();
      expect(
        container.read(provider).error,
        isNot(contains('private-request-details')),
      );
      expect(vm.confirm(), testPin);
      search.error = null;
      await vm.search();
      expect(container.read(provider).results, [testPlace]);
    },
  );

  test(
    'GPS denial preserves selection; GPS success can be adjusted by tapping',
    () async {
      final vm = container.read(provider.notifier);
      vm.selectPin(testPin);
      await vm.locate();
      expect(vm.confirm(), testPin);
      expect(container.read(provider).error, contains('tap the map'));
      locations.location = const GeoCoordinates(latitude: 10, longitude: 123);
      await vm.locate();
      expect(vm.confirm()!.label, 'Current location');
      vm.selectPin(testPin);
      expect(vm.confirm(), testPin);
    },
  );

  test(
    'initial photo or existing location is available when reopening picker',
    () {
      final initial = locationPickerViewModelProvider(testPlace);
      container.listen(initial, (_, _) {});
      expect(container.read(initial.notifier).confirm(), testPlace);
    },
  );
}
