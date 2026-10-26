import 'package:flutter/material.dart';

/// Presentation state for the community sightings map.
///
/// This deliberately contains no report coordinates. Community markers will
/// be introduced only after the privacy-preserving `community_reports` RPC is
/// available in the backend.
class CommunityMapState {
  const CommunityMapState({
    this.is3dEnabled = true,
    this.brightness = Brightness.light,
  });

  final bool is3dEnabled;
  final Brightness brightness;

  CommunityMapState copyWith({bool? is3dEnabled, Brightness? brightness}) {
    return CommunityMapState(
      is3dEnabled: is3dEnabled ?? this.is3dEnabled,
      brightness: brightness ?? this.brightness,
    );
  }
}
