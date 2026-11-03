import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import '../models/location_picker_state.dart';
import '../models/post_location.dart';
import '../models/post_draft.dart';
import '../services/location_search_service.dart';
import '../services/location_picker_map_service.dart';

class LocationPickerViewModel
    extends AutoDisposeFamilyNotifier<LocationPickerState, PostLocation?> {
  bool _disposed = false, _styleReady = false, _attached = false;
  bool _pendingRecenter = false;
  bool _initialized = false, _needs3d = true;
  PostLocation? _pendingFocus;
  int _searchRequest = 0, _locationRequest = 0;
  Future<void> _mapQueue = Future.value();
  late LocationPickerMapService _map;
  late LocationSearchService _search;

  @override
  LocationPickerState build(PostLocation? initial) {
    _map = ref.watch(locationPickerMapServiceProvider);
    _search = ref.watch(locationSearchServiceProvider);
    ref.onDispose(() {
      _disposed = true;
      _searchRequest++;
      _locationRequest++;
      _map.detach();
    });
    return LocationPickerState(
      selection: initial?.isValid == true ? initial : null,
    );
  }

  void onMapCreated(MapboxMap map) {
    _map.attach(map, onTap: selectPin);
    _attached = true;
    _render();
  }

  Future<void> onStyleLoaded() async {
    _styleReady = true;
    _needs3d = true;
    await _render();
  }

  /// Centers the opening map on GPS without changing the observation pin.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await _locate(select: false);
  }

  void onMapError() {
    if (!_disposed) state = state.copyWith(mapHasError: true);
  }

  void updateQuery(String query) {
    _searchRequest++;
    state = state.copyWith(
      query: query,
      results: [],
      hasSearched: false,
      isSearching: false,
    );
  }

  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) return;
    final request = ++_searchRequest;
    state = state.copyWith(isSearching: true, hasSearched: false, results: []);
    try {
      final results = await _search.search(query, proximity: state.selection);
      if (_disposed || request != _searchRequest) return;
      state = state.copyWith(
        isSearching: false,
        results: results,
        hasSearched: true,
      );
    } catch (error) {
      if (_disposed || request != _searchRequest) return;
      state = state.copyWith(
        isSearching: false,
        error: error is LocationSearchException
            ? error.message
            : 'Could not search places. Try again or tap the map.',
      );
    }
  }

  void selectPin(PostLocation location) => _select(location, recenter: false);
  void selectResult(PostLocation location) => _select(location, recenter: true);

  void _select(PostLocation location, {required bool recenter}) {
    if (_disposed || !location.isValid) return;
    _searchRequest++;
    _locationRequest++;
    state = state.copyWith(
      selection: location,
      results: [],
      isSearching: false,
      isLocating: false,
      hasSearched: false,
    );
    _pendingRecenter = recenter;
    _pendingFocus = null;
    _render();
  }

  Future<void> locate() => _locate(select: true);

  Future<void> _locate({required bool select}) async {
    if (state.isLocating) return;
    final request = ++_locationRequest;
    state = state.copyWith(isLocating: true);
    try {
      final gps = await ref
          .read(photoLocationServiceProvider)
          .currentLocation();
      if (_disposed || request != _locationRequest) return;
      if (gps == null ||
          !PostDraft.validCoordinates(gps.latitude, gps.longitude)) {
        state = state.copyWith(
          isLocating: false,
          error:
              'Could not get your location. Search for a place or tap the map instead.',
        );
        return;
      }
      final location = PostLocation(
        latitude: gps.latitude,
        longitude: gps.longitude,
        label: 'Current location',
      );
      if (select) {
        _select(location, recenter: true);
      } else {
        state = state.copyWith(isLocating: false);
        _pendingFocus = location;
        await _render();
      }
    } catch (_) {
      if (!_disposed && request == _locationRequest) {
        state = state.copyWith(
          isLocating: false,
          error:
              'Could not get your location. Search for a place or tap the map instead.',
        );
      }
    }
  }

  Future<void> _render() {
    _mapQueue = _mapQueue.then((_) async {
      if (_disposed || !_styleReady || !_attached) {
        return;
      }
      try {
        if (_needs3d) {
          await _map.configure3d();
          _needs3d = false;
        }
        if (_disposed) return;
        final focus = _pendingFocus;
        _pendingFocus = null;
        if (focus != null) await _map.focus(focus);
        if (_disposed) return;
        final recenter = _pendingRecenter;
        _pendingRecenter = false;
        if (state.selection != null) {
          await _map.showLocation(state.selection!, recenter: recenter);
        }
        if (!_disposed) {
          state = state.copyWith(mapHasError: false, error: state.error);
        }
      } catch (_) {
        onMapError();
      }
    });
    return _mapQueue;
  }

  PostLocation? confirm() => state.canConfirm ? state.selection : null;
}

final locationPickerViewModelProvider =
    AutoDisposeNotifierProviderFamily<
      LocationPickerViewModel,
      LocationPickerState,
      PostLocation?
    >(LocationPickerViewModel.new);
