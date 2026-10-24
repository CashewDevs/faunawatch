import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/features/profile_customization/models/profile_setup_state.dart';
import 'package:faunawatch/features/profile_customization/services/profile_service.dart';

export 'package:faunawatch/features/profile_customization/models/profile_setup_state.dart';

/// ViewModel managing state and input validation for the initial profile setup screen.
class ProfileSetupViewModel extends Notifier<ProfileSetupState> {
  late final ProfileService _profileService;

  @override
  ProfileSetupState build() {
    _profileService = ref.watch(profileServiceProvider);
    return const ProfileSetupState();
  }

  /// Updates the username in state.
  void onUsernameChanged(String value) {
    state = state.copyWith(username: value);
  }

  /// Updates the bio in state.
  void onBioChanged(String value) {
    state = state.copyWith(bio: value);
  }

  /// Submits the username and bio to [ProfileService].
  Future<bool> submit() async {
    if (!state.isContinueEnabled || state.isSubmitting) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final success = await _profileService.saveProfile(
        username: state.username.trim(),
        bio: state.bio.trim(),
      );
      state = state.copyWith(isSubmitting: false);
      return success;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save profile. Please try again.',
      );
      return false;
    }
  }
}

/// Riverpod provider exposing [ProfileSetupViewModel] and [ProfileSetupState].
final profileSetupViewModelProvider =
    NotifierProvider<ProfileSetupViewModel, ProfileSetupState>(
      ProfileSetupViewModel.new,
    );
