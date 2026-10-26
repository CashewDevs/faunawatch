import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';

/// Coordinates community-map presentation state with the Mapbox service.
class CommunityMapViewModel extends Notifier<CommunityMapState> {
  late final MapboxMapService _mapboxMapService;
  var _isStyleLoaded = false;

  @override
  CommunityMapState build() {
    _mapboxMapService = ref.watch(mapboxMapServiceProvider);
    ref.onDispose(_mapboxMapService.detach);
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
