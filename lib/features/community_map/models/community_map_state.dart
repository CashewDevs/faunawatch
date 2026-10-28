import 'package:flutter/material.dart';
import 'package:faunawatch/features/community_map/models/warning_demo.dart';

/// Presentation state for the community sightings map.
///
/// Demo coordinates are synthetic; no community reports or GPS are loaded.
class CommunityMapState {
  const CommunityMapState({
    this.is3dEnabled = true,
    this.brightness = Brightness.light,
    this.demoLevel = DemoWarningLevel.approaching,
    this.demoHasError = false,
    this.selectedPostId,
  });

  final bool is3dEnabled;
  final Brightness brightness;
  final DemoWarningLevel demoLevel;
  final bool demoHasError;
  final String? selectedPostId;

  CommunityMapState copyWith({
    bool? is3dEnabled,
    Brightness? brightness,
    DemoWarningLevel? demoLevel,
    bool? demoHasError,
    String? selectedPostId,
    bool clearSelectedPost = false,
  }) {
    return CommunityMapState(
      is3dEnabled: is3dEnabled ?? this.is3dEnabled,
      brightness: brightness ?? this.brightness,
      demoLevel: demoLevel ?? this.demoLevel,
      demoHasError: demoHasError ?? this.demoHasError,
      selectedPostId: clearSelectedPost
          ? null
          : selectedPostId ?? this.selectedPostId,
    );
  }
}
