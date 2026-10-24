import 'package:flutter/material.dart';

/// Immutable state representing profile banner and color selection.
class ProfileBannerState {
  const ProfileBannerState({
    this.selectedBanner,
    this.selectedColor,
    this.isSubmitting = false,
    this.errorMessage,
  });

  /// The asset path of the selected preset banner (e.g. day.webp, sunset.webp, night.webp).
  final String? selectedBanner;

  /// The selected accent color.
  final Color? selectedColor;

  final bool isSubmitting;
  final String? errorMessage;

  /// Whether either a preset banner OR an accent color is chosen (mutually exclusive).
  bool get isContinueEnabled =>
      (selectedBanner != null) ^ (selectedColor != null);

  ProfileBannerState copyWith({
    String? selectedBanner,
    Color? selectedColor,
    bool clearBanner = false,
    bool clearColor = false,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ProfileBannerState(
      selectedBanner: clearBanner
          ? null
          : (selectedBanner ?? this.selectedBanner),
      selectedColor: clearColor ? null : (selectedColor ?? this.selectedColor),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
