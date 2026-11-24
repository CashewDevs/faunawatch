import 'package:flutter/material.dart';
import 'community_report.dart';
import 'map_focus.dart';
import 'map_pin_filter.dart';
import 'map_pin_spot.dart';

/// Presentation state for the community sightings map.
///
/// Approved reports use approximate coordinates from the community RPC.
class CommunityMapState {
  const CommunityMapState({
    this.is3dEnabled = true,
    this.brightness = Brightness.light,
    this.selectedPostId,
    this.reports = const [],
    this.reportsHaveError = false,
    this.isLoadingReports = false,
    this.privateFocus,
    this.selectedSpot,
    this.filter = const MapPinFilter(),
  });

  final bool is3dEnabled;
  final Brightness brightness;
  final String? selectedPostId;
  final List<CommunityReport> reports;
  final bool reportsHaveError, isLoadingReports;

  /// The owner's pending or declined post shown with a temporary marker.
  final MapFocus? privateFocus;

  /// A tapped pin holding several posts; its list is open.
  final MapPinSpot? selectedSpot;

  /// Which posts are drawn as pins; FaunaGuard ignores it.
  final MapPinFilter filter;

  /// The posts drawn as pins: [reports] that match [filter].
  List<CommunityReport> get visibleReports => filter.apply(reports);

  CommunityMapState copyWith({
    bool? is3dEnabled,
    Brightness? brightness,
    String? selectedPostId,
    bool clearSelectedPost = false,
    List<CommunityReport>? reports,
    bool? reportsHaveError,
    bool? isLoadingReports,
    MapFocus? privateFocus,
    bool clearPrivateFocus = false,
    MapPinSpot? selectedSpot,
    bool clearSelectedSpot = false,
    MapPinFilter? filter,
  }) {
    return CommunityMapState(
      is3dEnabled: is3dEnabled ?? this.is3dEnabled,
      brightness: brightness ?? this.brightness,
      reports: reports ?? this.reports,
      reportsHaveError: reportsHaveError ?? this.reportsHaveError,
      isLoadingReports: isLoadingReports ?? this.isLoadingReports,
      selectedPostId: clearSelectedPost
          ? null
          : selectedPostId ?? this.selectedPostId,
      privateFocus: clearPrivateFocus
          ? null
          : privateFocus ?? this.privateFocus,
      selectedSpot: clearSelectedSpot
          ? null
          : selectedSpot ?? this.selectedSpot,
      filter: filter ?? this.filter,
    );
  }
}
