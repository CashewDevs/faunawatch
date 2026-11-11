import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/core/services/image_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
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
      // The category comes from the attached analysis until it is detached.
      category: state.aiResult == null ? category : null,
      latitude: latitude,
      longitude: longitude,
      description: description,
      species: species,
      notes: notes,
    );
  }

  /// Starts the draft from a FaunaLens [photo], with its [aiResult] when the
  /// user chose to use it. The result is saved with the post, and its category
  /// becomes the post's category.
  void usePhoto(FaunaLensPhoto photo, {AiIdentification? aiResult}) {
    if (state.isBusy) return;
    _request++;
    state = CreatePostState(
      category: aiResult?.category ?? state.category,
      description: state.description,
      species: state.species,
      notes: state.notes,
      photoPath: photo.path,
      aiResult: aiResult,
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

  /// Leaves the FaunaLens analysis out of the post. The photo and any
  /// species or category already in the form stay as they are.
  void removeAiResult() {
    if (state.isBusy || state.submittedId != null) return;
    _request++;
    state = state.copyWith(clearAiResult: true);
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
          // An analysis of the previous photo doesn't describe this one.
          clearAiResult: true,
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
      category: state.aiResult?.category ?? state.category!,
      latitude: double.parse(state.latitude),
      longitude: double.parse(state.longitude),
      description: state.description,
      species: state.species,
      notes: state.notes,
      photoPath: state.photoPath,
      aiResult: state.aiResult,
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
