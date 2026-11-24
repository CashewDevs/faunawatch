import 'package:flutter/material.dart';
import '../services/community_reports_service.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'dart:async';

import 'package:faunawatch/features/community_map/models/community_report.dart';
import 'package:faunawatch/features/community_map/models/map_focus.dart';
import 'package:faunawatch/features/community_map/models/map_pin_filter.dart';
import 'package:faunawatch/features/community_map/models/map_pin_spot.dart';
import 'package:faunawatch/features/community_map/services/map_pin_photo_service.dart';
import 'package:faunawatch/features/feed/models/feed_post.dart';
import 'package:faunawatch/features/report_detail/services/report_detail_service.dart';
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

  /// Photo pins load this many at a time, and at most [_photosPerPass] each
  /// time the map stops moving, so a zoomed-out view cannot download every
  /// photo at once.
  static const photosAtOnce = 4, _photosPerPass = 24;

  /// Pin pictures loaded this session, by report id.
  final _pinPhotos = <String, StyleImage>{};

  /// Reports whose photo could not be loaded; retried after a manual refresh.
  final _failedPhotos = <String>{};
  bool _loadingPhotos = false, _photosAgain = false;
  int _photoGeneration = 0;

  /// The latest pin redraw after a filter change; the next one waits for it.
  Future<void> _pinRedraws = Future.value();

  /// The filter the pins on the map were last drawn with; null before the
  /// first successful drawing on this map. Differs from the state's filter
  /// when a drawing failed or a refresh failed after the filter changed.
  MapPinFilter? _drawnFilter;

  /// The refresh in progress, so a second request waits for it.
  Future<void>? _refreshing;

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
      if (previous == next) return;
      dismissPrivateFocus();
      _forgetPinPhotos();
      // The next person starts with every pin, not the last one's filter.
      unawaited(clearFilter());
    });
    // The map stays alive in the background, so posts approved meanwhile
    // appear when it is opened again.
    ref.listen(shellViewModelProvider, (previous, next) {
      if (next == ShellDestination.map && previous != ShellDestination.map) {
        _refreshIfStale();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _mapboxMapService.detach();
    });
    return const CommunityMapState();
  }

  /// Opening the Map tab reloads the posts unless they loaded this recently,
  /// so switching tabs back and forth does not reload every time.
  static const reloadAfter = Duration(seconds: 30);

  /// When the posts last loaded successfully.
  DateTime? _loadedAt;

  void _refreshIfStale() {
    final loadedAt = _loadedAt;
    final now = ref.read(communityMapClockProvider)();
    if (loadedAt != null && now.difference(loadedAt) < reloadAfter) return;
    unawaited(refreshReports());
  }

  /// Connects the platform map after it has been created.
  Future<void> onMapCreated(MapboxMap mapboxMap) async {
    _isStyleLoaded = false;
    _hasCenteredReports = false;
    // A new map has no pins yet.
    _drawnFilter = null;
    await _mapboxMapService.attach(mapboxMap, onPostTap: onPinTap);
  }

  /// A tapped pin: one post opens its card; several open their list.
  void onPinTap(String postId) {
    if (_disposed) return;
    final spot = groupReportsBySpot(
      state.visibleReports,
    ).where((spot) => spot.reports.any((r) => r.id == postId)).firstOrNull;
    if (spot == null) return;
    if (spot.count == 1) {
      selectPost(postId);
    } else {
      state = state.copyWith(selectedSpot: spot, clearSelectedPost: true);
    }
  }

  /// Closes the list of posts sharing a pin.
  void dismissSpot() => state = state.copyWith(clearSelectedSpot: true);

  void selectPost(String postId) {
    if (!_disposed && state.reports.any((report) => report.id == postId)) {
      state = state.copyWith(selectedPostId: postId);
    }
  }

  void dismissPost() => state = state.copyWith(clearSelectedPost: true);

  /// Opens the poster's profile from a pin's card or list: the signed-in
  /// user's own goes to the Profile tab, anyone else's to their public
  /// profile through [openOtherProfile].
  void openAuthor(String authorId, void Function(String) openOtherProfile) {
    if (authorId.trim().isEmpty) return;
    if (authorId == ref.read(currentUserIdProvider).valueOrNull) {
      ref
          .read(shellViewModelProvider.notifier)
          .selectDestination(ShellDestination.profile);
    } else {
      openOtherProfile(authorId);
    }
  }

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

  /// Opens the Map tab at [post]'s spot after its location was tapped.
  ///
  /// The signed-in user's own post (any status) is shown at its exact point,
  /// read through owner access, with the owner-only marker. Anyone else's post
  /// is shown at its rounded point, where its public pin is. If the exact
  /// point cannot be read, the rounded one is used.
  Future<void> focusOnPost(FeedPost post, {required bool isPublic}) async {
    // Switch at once; the exact point arrives a moment later.
    ref.read(shellViewModelProvider.notifier).goTo(ShellDestination.map);
    MapFocus? focus;
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId != null && post.authorId == userId) {
      try {
        final point = await ref
            .read(reportDetailServiceProvider)
            .fetchOwnLocation(post.id);
        if (point != null) {
          focus = MapFocus(
            postId: post.id,
            latitude: point.latitude,
            longitude: point.longitude,
            isPublic: isPublic,
            isExact: true,
          );
        }
      } catch (_) {
        // Fall back to the rounded point below.
      }
      // Another account signed in while the point was loading.
      if (_disposed || ref.read(currentUserIdProvider).valueOrNull != userId) {
        return;
      }
    }
    focus ??= MapFocus.fromPost(post, isPublic: isPublic);
    if (focus != null) await focusOn(focus);
  }

  /// Opens the Map tab at [focus]. An approved post's pin sits in the middle;
  /// the owner's exact point and posts that are not public get a temporary
  /// marker only the owner sees. If the map has not loaded yet, the spot is
  /// shown as soon as it has.
  Future<void> focusOn(MapFocus focus) async {
    // One step, so Back returns to where the location was tapped.
    ref.read(shellViewModelProvider.notifier).goTo(ShellDestination.map);
    state = focus.showsOwnerMarker
        ? state.copyWith(clearSelectedPost: true, privateFocus: focus)
        : state.copyWith(clearSelectedPost: true, clearPrivateFocus: true);
    _pendingFocus = focus;
    if (_isStyleLoaded) await _applyFocus();
  }

  /// Removes the owner-only marker.
  Future<void> dismissPrivateFocus() async {
    if (_disposed) return;
    if (_pendingFocus?.showsOwnerMarker ?? false) _pendingFocus = null;
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
    // A post approved since the last refresh has no pin yet. Opening the Map
    // tab may already be refreshing; then this waits for that refresh, so
    // the filter check below sees the post.
    if (focus.isPublic && !state.reports.any((r) => r.id == focus.postId)) {
      await refreshReports();
    }
    if (_disposed) return;
    // The filter must not hide the pin that was asked for.
    final report = state.reports.where((r) => r.id == focus.postId).firstOrNull;
    if (focus.isPublic && report != null && !state.filter.matches(report)) {
      await clearFilter();
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

  /// Loads the photo pins of the reports on screen that do not have one yet.
  /// Called whenever the map stops moving and after the reports change.
  Future<void> onMapIdle() async {
    if (_disposed || !_isStyleLoaded) return;
    if (_loadingPhotos) {
      // Moved again while loading: check the new area afterwards.
      _photosAgain = true;
      return;
    }
    _loadingPhotos = true;
    try {
      do {
        _photosAgain = false;
        await _loadVisiblePhotos();
      } while (_photosAgain && !_disposed);
    } finally {
      _loadingPhotos = false;
    }
  }

  Future<void> _loadVisiblePhotos() async {
    final generation = _photoGeneration;
    // A shared pin shows only its newest post's photo.
    final waiting = [
      for (final report in groupReportsBySpot(
        state.visibleReports,
      ).map((spot) => spot.top))
        if (report.photoPath != null &&
            !_pinPhotos.containsKey(report.id) &&
            !_failedPhotos.contains(report.id))
          report,
    ];
    if (waiting.isEmpty) return;
    final MapBounds? bounds;
    try {
      bounds = await _mapboxMapService.visibleBounds();
    } catch (_) {
      return;
    }
    if (bounds == null || _disposed) return;
    final visible = waiting
        .where((report) => _isInside(report, bounds!))
        .take(_photosPerPass)
        .toList();
    if (visible.isEmpty) return;
    final photos = ref.read(mapPinPhotoServiceProvider);
    for (var start = 0; start < visible.length; start += photosAtOnce) {
      final batch = visible.skip(start).take(photosAtOnce).toList();
      final images = await Future.wait([
        for (final report in batch) photos.loadPin(report.photoPath!),
      ]);
      // An account change or dispose meanwhile discards these.
      if (_disposed || generation != _photoGeneration) return;
      final loaded = <String, StyleImage>{};
      for (var i = 0; i < batch.length; i++) {
        final image = images[i];
        if (image == null) {
          _failedPhotos.add(batch[i].id);
        } else {
          _pinPhotos[batch[i].id] = image;
          loaded[batch[i].id] = image;
        }
      }
      try {
        await _mapboxMapService.showPinPhotos(loaded);
      } catch (_) {
        // Kept in memory; shown again with the next refresh.
      }
    }
  }

  static bool _isInside(CommunityReport report, MapBounds bounds) {
    if (report.latitude < bounds.south || report.latitude > bounds.north) {
      return false;
    }
    // A view across the date line has west > east.
    return bounds.west <= bounds.east
        ? report.longitude >= bounds.west && report.longitude <= bounds.east
        : report.longitude >= bounds.west || report.longitude <= bounds.east;
  }

  void _forgetPinPhotos() {
    _photoGeneration++;
    _pinPhotos.clear();
    _failedPhotos.clear();
  }

  /// Reloads the posts and redraws the pins. While a refresh is running,
  /// another call waits for it instead of starting a second one.
  Future<void> refreshReports() {
    if (!_isStyleLoaded) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    // A refresh retries photos that failed before.
    _failedPhotos.clear();
    state = state.copyWith(isLoadingReports: true, reportsHaveError: false);
    try {
      final reports = await ref.read(communityReportsServiceProvider).load();
      if (_disposed) return;
      // A filter change waits for the refresh, and the refresh for an
      // earlier filter redraw, so the pins are never drawn twice at once.
      await _pinRedraws;
      if (_disposed) return;
      final drawnFilter = state.filter.keptAfterRefresh(reports);
      final visible = drawnFilter.apply(reports);
      await _mapboxMapService.showReports(
        visible,
        recenter:
            !_hasCenteredReports &&
            visible.isNotEmpty &&
            !ref.read(faunaGuardViewModelProvider).isEnabled,
      );
      _drawnFilter = drawnFilter;
      if (!_disposed) {
        _loadedAt = ref.read(communityMapClockProvider)();
        // Counted even when the filter hides every pin, so clearing it
        // later never makes a refresh jump the camera.
        if (reports.isNotEmpty) _hasCenteredReports = true;
        state = state.copyWith(
          reports: List.unmodifiable(reports),
          filter: state.filter.keptAfterRefresh(reports),
          isLoadingReports: false,
          clearSelectedPost: !reports.any((r) => r.id == state.selectedPostId),
        );
        // The filter changed while the pins were being drawn.
        if (state.filter != _drawnFilter) await _redrawPins();
        await _updateGuardRadius();
        await _showKnownPinPhotos();
        unawaited(onMapIdle());
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(reportsHaveError: true, isLoadingReports: false);
        // A filter picked during the failed refresh still needs drawing,
        // over the posts already loaded.
        if (state.filter != _drawnFilter) await _redrawPins();
      }
    }
  }

  /// Puts back the photo pins already loaded, e.g. after the style reloaded.
  Future<void> _showKnownPinPhotos() async {
    final known = {
      for (final report in state.reports) report.id: ?_pinPhotos[report.id],
    };
    if (known.isEmpty || _disposed) return;
    try {
      await _mapboxMapService.showPinPhotos(known);
    } catch (_) {
      // The pins keep the logo until the next refresh.
    }
  }

  /// Shows only the posts [filter] lets through. Species ticks that no
  /// longer appear in the ticked categories are dropped. The camera does not
  /// move, and FaunaGuard keeps using every post.
  Future<void> setFilter(MapPinFilter filter) async {
    if (_disposed) return;
    final next = filter.prunedFor(state.reports);
    // The same filter again redraws only if its pins failed to draw.
    if (next == state.filter && next == _drawnFilter) return;
    state = state.copyWith(filter: next);
    // A refresh in progress draws the new filter when it finishes.
    if (state.isLoadingReports) return;
    await _redrawPins();
    // A shared pin may now show another post, whose photo may be missing.
    unawaited(onMapIdle());
  }

  /// Shows every post again.
  Future<void> clearFilter() => setFilter(const MapPinFilter());

  /// Draws the pins for the current filter once any earlier redraw is done,
  /// so two quick changes cannot finish in the wrong order.
  Future<void> _redrawPins() {
    return _pinRedraws = _pinRedraws.then((_) async {
      if (_disposed || !_isStyleLoaded) return;
      final filter = state.filter;
      try {
        await _mapboxMapService.showReports(filter.apply(state.reports));
        _drawnFilter = filter;
      } catch (_) {
        // The pins stay as they were; applying the filter again or the next
        // refresh draws them again.
      }
    });
  }

  /// The filter sheet's lists and counts, from the posts loaded now.
  MapFilterChoices get filterChoices => MapFilterChoices(state.reports);

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

/// The current time, injectable so tests can check [CommunityMapViewModel.reloadAfter].
final communityMapClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Provider exposing the community-map presentation state and actions.
final communityMapViewModelProvider =
    NotifierProvider<CommunityMapViewModel, CommunityMapState>(
      CommunityMapViewModel.new,
    );
