import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';

/// Coordinates community-map presentation state with the Mapbox service.
class CommunityMapViewModel extends Notifier<CommunityMapState> {
  late final MapboxMapService _mapboxMapService;
  var _isStyleLoaded = false;
  var _disposed = false;
  Future<void> _demoQueue = Future.value();

  @override
  CommunityMapState build() {
    _mapboxMapService = ref.watch(mapboxMapServiceProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _mapboxMapService.detach();
    });
    return const CommunityMapState();
  }

  /// Connects the platform map after it has been created.
  Future<void> onMapCreated(MapboxMap mapboxMap) async {
    await _mapboxMapService.attach(mapboxMap);
  }

  /// Applies the current appearance only after Mapbox has finished loading the
  /// Standard style and its `basemap` import.
  Future<void> onStyleLoaded() async {
    _isStyleLoaded = true;
    await _applyAppearance();
    await _renderDemo();
  }

  Future<void> selectDemoLevel(DemoWarningLevel level) async {
    state = state.copyWith(demoLevel: level);
    if (_isStyleLoaded) await _renderDemo();
  }

  Future<void> recenterDemo() async {
    if (_isStyleLoaded) await _renderDemo(recenter: true);
  }

  // Serialize updates so fast selections cannot create duplicate style layers
  // or leave the marker showing an older selection.
  Future<void> _renderDemo({bool recenter = false}) {
    _demoQueue = _demoQueue.then((_) async {
      if (_disposed) return;
      try {
        await _mapboxMapService.showWarningDemo(
          state.demoLevel,
          recenter: recenter,
        );
        if (!_disposed) state = state.copyWith(demoHasError: false);
      } catch (_) {
        if (!_disposed) state = state.copyWith(demoHasError: true);
      }
    });
    return _demoQueue;
  }

  /// Keeps Mapbox Standard lighting aligned with the active app theme.
  Future<void> setBrightness(Brightness brightness) async {
    if (state.brightness == brightness) {
      return;
    }
    state = state.copyWith(brightness: brightness);
    if (_isStyleLoaded) {
      await _applyAppearance();
    }
  }

  /// Switches between a pitched 3D view and an overhead 2D view.
  Future<void> toggle3d() async {
    state = state.copyWith(is3dEnabled: !state.is3dEnabled);
    if (_isStyleLoaded) {
      await _applyAppearance();
    }
  }

  Future<void> _applyAppearance() {
    return _mapboxMapService.applyAppearance(
      brightness: state.brightness,
      is3dEnabled: state.is3dEnabled,
    );
  }
}

/// Provider exposing the community-map presentation state and actions.
final communityMapViewModelProvider =
    NotifierProvider<CommunityMapViewModel, CommunityMapState>(
      CommunityMapViewModel.new,
    );
