import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import '../models/create_post_state.dart';
import '../models/post_draft.dart';
import '../models/post_location.dart';
import '../services/create_post_service.dart';

class CreatePostViewModel extends Notifier<CreatePostState> {
  var _request = 0;
  var _disposed = false;

  @override
  CreatePostState build() {
    // Do not carry one user's draft over to another account.
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous?.hasValue == true &&
          previous?.valueOrNull != next.valueOrNull) {
        _request++;
        state = const CreatePostState();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _request++;
    });
    return const CreatePostState();
  }

  void edit({
    ReportCategory? category,
    String? latitude,
    String? longitude,
    String? description,
    String? species,
    String? notes,
  }) {
    if (state.isBusy || state.submittedId != null) return;
    _request++;
    state = state.copyWith(
      category: category,
      latitude: latitude,
      longitude: longitude,
      description: description,
      species: species,
      notes: notes,
    );
  }

  void usePhoto(FaunaLensPhoto photo) {
    if (state.isBusy) return;
    _request++;
    state = CreatePostState(
      category: state.category,
      description: state.description,
      species: state.species,
      notes: state.notes,
      photoPath: photo.path,
      latitude: photo.coordinates?.latitude.toString() ?? '',
      longitude: photo.coordinates?.longitude.toString() ?? '',
      locationLabel: 'Photo location',
    );
  }

  void setLocation(PostLocation location) {
    if (state.isBusy || state.submittedId != null || !location.isValid) return;
    _request++;
    state = state.copyWith(
      latitude: location.latitude.toString(),
      longitude: location.longitude.toString(),
      locationLabel: location.label,
    );
  }

  void removePhoto() {
    if (!state.isBusy) {
      _request++;
      state = state.copyWith(clearPhoto: true);
    }
  }

  void reset() {
    if (!state.isBusy) {
      _request++;
      state = const CreatePostState();
    }
  }

  Future<void> pickPhoto() async {
    if (state.isBusy) return;
    final request = ++_request;
    state = state.copyWith(isBusy: true);
    try {
      final path = await ref.read(imagePickerServiceProvider).pickImage();
      if (_disposed || request != _request) return;
      if (path != null) {
        GeoCoordinates? gps;
        try {
          gps = await ref
              .read(photoLocationServiceProvider)
              .locationInPhoto(path);
        } catch (_) {
          /* Manual location remains available. */
        }
        if (_disposed || request != _request) return;
        state = state.copyWith(
          photoPath: path,
          latitude: gps?.latitude.toString(),
          longitude: gps?.longitude.toString(),
          locationLabel: gps == null ? null : 'Photo location',
        );
      }
      state = state.copyWith(isBusy: false);
    } catch (_) {
      if (!_disposed && request == _request) {
        state = state.copyWith(
          isBusy: false,
          error: 'Could not open your photos. Please try again.',
        );
      }
    }
  }

  Future<void> locate() async {
    if (state.isBusy) return;
    final request = ++_request;
    state = state.copyWith(isBusy: true);
    GeoCoordinates? gps;
    try {
      gps = await ref.read(photoLocationServiceProvider).currentLocation();
    } catch (_) {
      /* Show the same actionable location message. */
    }
    if (_disposed || request != _request) return;
    state = state.copyWith(
      isBusy: false,
      latitude: gps?.latitude.toString(),
      longitude: gps?.longitude.toString(),
      locationLabel: gps == null ? null : 'Current location',
      error: gps == null
          ? 'Could not get your location. Enable location access or choose a location on the map.'
          : null,
    );
  }

  Future<bool> submit() async {
    if (state.isBusy || state.submittedId != null) return false;
    if (!state.canSubmit) {
      state = state.copyWith(
        error:
            'Choose a category and select an observation location on the map.',
      );
      return false;
    }
    final request = ++_request;
    final draft = PostDraft(
      category: state.category!,
      latitude: double.parse(state.latitude),
      longitude: double.parse(state.longitude),
      description: state.description,
      species: state.species,
      notes: state.notes,
      photoPath: state.photoPath,
    );
    state = state.copyWith(isBusy: true);
    try {
      final id = await ref.read(createPostServiceProvider).submit(draft);
      if (_disposed || request != _request) return false;
      state = state.copyWith(isBusy: false, submittedId: id);
      return true;
    } catch (error) {
      if (!_disposed && request == _request) {
        state = state.copyWith(
          isBusy: false,
          error: error is PostSubmissionException
              ? error.message
              : 'Could not submit your post. Please try again.',
        );
      }
      return false;
    }
  }
}

final createPostViewModelProvider =
    NotifierProvider<CreatePostViewModel, CreatePostState>(
      CreatePostViewModel.new,
    );
