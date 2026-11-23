import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/public_profile/models/public_profile_state.dart';
import 'package:faunawatch/features/public_profile/services/public_profile_service.dart';
import 'package:faunawatch/features/public_profile/viewmodels/public_profile_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The profile preview sheet's state: one account's public identity (banner,
/// picture, name, bio) and the Message action. Unlike the full profile it
/// never loads the account's posts, so the sheet opens quickly.
///
/// Reuses [PublicProfileState]; its post fields stay empty.
class ProfilePreviewViewModel
    extends AutoDisposeFamilyNotifier<PublicProfileState, String>
    with PublicProfileChat {
  late PublicProfileService _service;
  int _generation = 0;

  @override
  int get loadGeneration => _generation;

  @override
  PublicProfileState build(String arg) {
    final viewerId = ref.watch(currentUserIdProvider).valueOrNull;
    _service = ref.watch(publicProfileServiceProvider);
    final generation = ++_generation;
    ref.onDispose(() => ++_generation);
    if (viewerId == null) return const PublicProfileState();
    Future.microtask(() => _load(generation));
    return const PublicProfileState(isLoading: true);
  }

  Future<void> _load(int generation) async {
    if (generation != _generation) return;
    try {
      final profile = await _service.fetchProfile(arg);
      if (generation == _generation) {
        state = PublicProfileState(profile: profile);
      }
    } catch (_) {
      if (generation == _generation) {
        state = const PublicProfileState(hasError: true);
      }
    }
  }

  /// Loads the profile again after a failure.
  Future<void> retry() async {
    if (state.isLoading) return;
    state = const PublicProfileState(isLoading: true);
    await _load(++_generation);
  }
}

final profilePreviewViewModelProvider = NotifierProvider.autoDispose
    .family<ProfilePreviewViewModel, PublicProfileState, String>(
      ProfilePreviewViewModel.new,
    );
