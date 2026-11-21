import 'package:flutter/material.dart';
import '../services/community_reports_service.dart';
import 'package:faunawatch/features/fauna_guard/models/guard_location.dart';
import 'package:faunawatch/features/fauna_guard/viewmodels/fauna_guard_viewmodel.dart';
import 'package:faunawatch/features/community_map/models/map_post_preview.dart';
import 'package:faunawatch/features/feed/viewmodels/feed_viewmodel.dart';
import 'package:faunawatch/features/shell/viewmodels/shell_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:faunawatch/features/community_map/models/community_map_state.dart';
import 'package:faunawatch/features/community_map/services/mapbox_map_service.dart';

/// Coordinates community-map presentation state with the Mapbox service.
class CommunityMapViewModel extends Notifier<CommunityMapState> {
  late final MapboxMapService _mapboxMapService;
  var _isStyleLoaded = false;
  var _disposed = false;
  var _hasCenteredReports = false;
  bool _updatingGuard = false;
  int _guardRevision = 0;

  @override
  CommunityMapState build() {
    _mapboxMapService = ref.watch(mapboxMapServiceProvider);
    _disposed = false;
    ref.listen(
      faunaGuardViewModelProvider.select((guard) => guard.location),
      (_, next) => _updateGuardLocation(),
    );
    ref.listen(
      faunaGuardViewModelProvider.select((guard) => guard.isEnabled),
      (_, next) => _updateGuardRadius(),
    );
    ref.onDispose(() {
      _disposed = true;
      _mapboxMapService.detach();
    });
    return const CommunityMapState();
  }

  /// Connects the platform map after it has been created.
  Future<void> onMapCreated(MapboxMap mapboxMap) async {
    _isStyleLoaded = false;
    _hasCenteredReports = false;
    await _mapboxMapService.attach(mapboxMap, onPostTap: selectPost);
  }

  void selectPost(String postId) {
    if (!_disposed && state.reports.any((report) => report.id == postId)) {
      state = state.copyWith(selectedPostId: postId);
    }
  }

  void dismissPost() => state = state.copyWith(clearSelectedPost: true);

  /// Opens the tapped report in the For You feed.
  void seeMore() {
    final postId = state.selectedPostId;
    if (postId == null || selectedPreview == null) return;
    ref.read(feedViewModelProvider.notifier).openReport(postId);
    dismissPost();
    ref
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.feed);
  }

  /// Applies the current appearance only after Mapbox has finished loading the
  /// Standard style and its `basemap` import.
  Future<void> onStyleLoaded() async {
    _isStyleLoaded = true;
    await _applyAppearance();
    await refreshReports();
    await _updateGuardLocation();
  }

  /// Shows FaunaGuard's 1 km / 500 m rings around the map's reports only
  /// while FaunaGuard is on.
  Future<void> _updateGuardRadius() async {
    if (_disposed || !_isStyleLoaded) return;
    final enabled = ref.read(faunaGuardViewModelProvider).isEnabled;
    try {
      await _mapboxMapService.showGuardRadius(
        enabled ? state.reports : const [],
      );
    } catch (_) {
      // Alerts keep working without the rings; the next refresh retries.
    }
  }

  Future<void> _updateGuardLocation() async {
    ++_guardRevision;
    if (_disposed || !_isStyleLoaded || _updatingGuard) return;
    _updatingGuard = true;
    try {
      int revision;
      do {
        revision = _guardRevision;
        final GuardLocation? location = ref
            .read(faunaGuardViewModelProvider)
            .location;
        await _mapboxMapService.showGuardLocation(location);
      } while (!_disposed && revision != _guardRevision);
    } catch (_) {
      // GPS alerts remain active if the map renderer is temporarily unavailable.
      // A later fix or style reload retries the marker.
    } finally {
      _updatingGuard = false;
    }
  }

  MapPostPreview? get selectedPreview {
    return state.reports
        .where((r) => r.id == state.selectedPostId)
        .firstOrNull
        ?.preview;
  }

  Future<void> refreshReports() async {
    if (!_isStyleLoaded || state.isLoadingReports) return;
    state = state.copyWith(isLoadingReports: true, reportsHaveError: false);
    try {
      final reports = await ref.read(communityReportsServiceProvider).load();
      if (_disposed) return;
      await _mapboxMapService.showReports(
        reports,
        recenter:
            !_hasCenteredReports &&
            reports.isNotEmpty &&
            !ref.read(faunaGuardViewModelProvider).isEnabled,
      );
      if (!_disposed) {
        if (reports.isNotEmpty) _hasCenteredReports = true;
        state = state.copyWith(
          reports: List.unmodifiable(reports),
          isLoadingReports: false,
          clearSelectedPost: !reports.any((r) => r.id == state.selectedPostId),
        );
        await _updateGuardRadius();
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(reportsHaveError: true, isLoadingReports: false);
      }
    }
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
