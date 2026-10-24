import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/profile_customization/models/profile_banner_state.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

/// ViewModel managing profile banner and color selection presentation state.
class ProfileBannerViewModel extends StateNotifier<ProfileBannerState> {
  ProfileBannerViewModel(this._profileService)
    : super(const ProfileBannerState());

  final ProfileService _profileService;

  /// Selects a banner preset (e.g. day.webp, sunset.webp, night.webp), clearing any selected color.
  void selectBanner(String assetPath) {
    state = state.copyWith(selectedBanner: assetPath, clearColor: true);
  }

  /// Selects an accent color, clearing any selected banner preset.
  void selectColor(Color color) {
    state = state.copyWith(selectedColor: color, clearBanner: true);
  }

  /// Submits the chosen banner or color.
  Future<bool> submit() async {
    if (!state.isContinueEnabled) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final success = await _profileService.saveProfileBanner(
        bannerAsset: state.selectedBanner,
        colorValue: state.selectedColor?.toARGB32(),
      );

      if (mounted) {
        state = state.copyWith(isSubmitting: false);
      }
      return success;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Failed to save banner: $e',
        );
      }
      return false;
    }
  }
}

/// Riverpod provider for [ProfileBannerViewModel].
final profileBannerViewModelProvider =
    StateNotifierProvider<ProfileBannerViewModel, ProfileBannerState>((ref) {
      final profileService = ref.watch(profileServiceProvider);
      return ProfileBannerViewModel(profileService);
    });
