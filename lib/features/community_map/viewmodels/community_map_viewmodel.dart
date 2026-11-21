import 'package:flutter/material.dart';
import '../services/community_reports_service.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
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

  /// A focus requested before the map finished loading.
  MapFocus? _pendingFocus;

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
    // Another account must never see the previous owner's marker.
    ref.listen(currentUserIdProvider.select((user) => user.valueOrNull), (
      previous,
      next,
    ) {
      if (previous != next) dismissPrivateFocus();
    });
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

  /// Opens the Map tab at a post's approximate spot, e.g. after its location
  /// was tapped. An approved post's pin sits in the middle; a post that is not
  /// public gets a temporary marker only its owner sees. If the map has not
  /// loaded yet, the spot is shown as soon as it has.
  Future<void> focusOn(MapFocus focus) async {
    ref
        .read(shellViewModelProvider.notifier)
        .selectDestination(ShellDestination.feed);
    ref.read(feedTabViewModelProvider.notifier).select(FeedTab.map);
    state = focus.isPublic
        ? state.copyWith(clearSelectedPost: true, clearPrivateFocus: true)
        : state.copyWith(clearSelectedPost: true, privateFocus: focus);
    _pendingFocus = focus;
    if (_isStyleLoaded) await _applyFocus();
  }

  /// Removes the owner-only marker.
  Future<void> dismissPrivateFocus() async {
    if (_disposed) return;
    if (_pendingFocus?.isPublic == false) _pendingFocus = null;
    if (state.privateFocus == null) return;
    state = state.copyWith(clearPrivateFocus: true);
    if (!_isStyleLoaded) return;
    try {
      await _mapboxMapService.showFocus(null);
    } catch (_) {
      // The marker goes with the next style load.
    }
  }

  Future<void> _applyFocus() async {
    final focus = _pendingFocus;
    if (focus == null || _disposed) return;
    _pendingFocus = null;
    // The first report load must not move the camera away again.
    _hasCenteredReports = true;
    // A post approved since the last refresh has no pin yet.
    if (focus.isPublic && !state.reports.any((r) => r.id == focus.postId)) {
      await refreshReports();
    }
    if (_disposed) return;
    try {
      await _mapboxMapService.showFocus(focus);
    } catch (_) {
      // The map stays usable; tapping the location again retries.
    }
  }

  /// Applies the current appearance only after Mapbox has finished loading the
  /// Standard style and its `basemap` import.
  Future<void> onStyleLoaded() async {
    _isStyleLoaded = true;
    await _applyAppearance();
    // A requested spot wins over fitting every report into view.
    if (_pendingFocus != null) _hasCenteredReports = true;
    await refreshReports();
    await _updateGuardLocation();
    if (_pendingFocus != null) {
      await _applyFocus();
    } else if (state.privateFocus != null) {
      // A reloaded style lost the marker; redraw it without moving.
      try {
        await _mapboxMapService.showFocus(
          state.privateFocus,
          moveCamera: false,
        );
      } catch (_) {
        // Shown again the next time the location is tapped.
      }
    }
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
