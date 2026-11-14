import 'package:flutter/material.dart';
import 'community_report.dart';

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
  });

  final bool is3dEnabled;
  final Brightness brightness;
  final String? selectedPostId;
  final List<CommunityReport> reports;
  final bool reportsHaveError, isLoadingReports;

  CommunityMapState copyWith({
    bool? is3dEnabled,
    Brightness? brightness,
    String? selectedPostId,
    bool clearSelectedPost = false,
    List<CommunityReport>? reports,
    bool? reportsHaveError,
    bool? isLoadingReports,
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
    );
  }
}
