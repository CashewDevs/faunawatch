import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/profile/models/profile_tag.dart';
import 'package:faunawatch/features/profile/models/profile_tag_state.dart';
import 'package:faunawatch/features/profile/services/profile_tag_service.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/suspension/models/account_suspension.dart';
import 'package:faunawatch/features/suspension/viewmodels/account_suspension_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suggestions never change the public profile until an explicit confirmation.
class ProfileTagViewModel extends AutoDisposeNotifier<ProfileTagState> {
  late ProfileTagService _service;
  int _generation = 0;

  @override
  ProfileTagState build() {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    _service = ref.watch(profileTagServiceProvider);
    final generation = ++_generation;
    ref.onDispose(() => ++_generation);
    if (userId == null) return const ProfileTagState();
    Future.microtask(() => _load(generation, _service));
    return const ProfileTagState(isLoading: true);
  }

  Future<void> _load(int generation, ProfileTagService service) async {
    if (generation != _generation) return;
    try {
      final activity = await service.fetchActivity();
      if (generation == _generation) {
        state = ProfileTagState(activity: activity);
      }
    } catch (_) {
      if (generation == _generation) {
        state = const ProfileTagState(
          errorMessage: 'Could not load tag suggestions. Please try again.',
        );
      }
    }
  }

  Future<void> retry() async {
    if (state.isLoading || state.isSaving) return;
    state = const ProfileTagState(isLoading: true);
    await _load(++_generation, _service);
  }

  Future<bool> confirm(ProfileTag tag) => _save(tag);
  Future<bool> remove() => _save(null);

  Future<bool> _save(ProfileTag? tag) async {
    if (state.isLoading || state.isSaving) return false;
    final userId = ref.read(currentUserIdProvider).valueOrNull;
    if (userId == null) return false;
    final suspension = ref.read(accountSuspensionViewModelProvider);
    if (suspension != null) {
      state = state.copyWith(
        errorMessage: suspension.blockedMessage(SuspendedAction.editProfile),
      );
      return false;
    }
    if (tag != null && !(state.activity?.suggestions.contains(tag) ?? false)) {
      return false;
    }

    final generation = _generation;
    final keepAlive = ref.keepAlive();
    state = state.copyWith(isSaving: true);
    try {
      final saved = await _service.saveTag(tag);
      if (generation != _generation ||
          ref.read(currentUserIdProvider).valueOrNull != userId) {
        return false;
      }
      if (!saved) throw StateError('Profile tag was not saved.');
      ref.read(profileViewModelProvider.notifier).updateProfileTag(tag);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      if (generation == _generation) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Could not save your profile tag. Please try again.',
        );
      }
      return false;
    } finally {
      keepAlive.close();
    }
  }
}

final profileTagViewModelProvider =
    NotifierProvider.autoDispose<ProfileTagViewModel, ProfileTagState>(
      ProfileTagViewModel.new,
    );
