import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/fauna_lens/models/fauna_lens_state.dart';
import 'package:faunawatch/features/fauna_lens/services/photo_location_service.dart';
import 'package:faunawatch/features/gallery/viewmodels/gallery_viewmodel.dart';
import '../models/create_post_state.dart';
import '../models/post_draft.dart';
import '../models/post_location.dart';
import '../models/post_photo_source.dart';
import '../services/create_post_service.dart';
import '../services/location_preview_service.dart';
import '../services/post_photo_picker_service.dart';

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
  ///
  /// The photo's location replaces the draft's. A photo without one keeps a
  /// location the user chose themselves, but not one taken from an earlier
  /// photo, which may have been somewhere else.
  void usePhoto(FaunaLensPhoto photo, {AiIdentification? aiResult}) {
    if (state.isBusy) return;
    _request++;
    final gps = photo.coordinates;
    final keepLocation =
        gps == null &&
        state.locationLabel != CreatePostState.photoLocationLabel;
    state = CreatePostState(
      category: aiResult?.category ?? state.category,
      description: state.description,
      species: state.species,
      notes: state.notes,
      photoPath: photo.path,
      // "Change photo" swaps only the cover; photos added on the form stay.
      extraPhotoPaths: state.extraPhotoPaths,
      aiResult: aiResult,
      latitude:
          gps?.latitude.toString() ?? (keepLocation ? state.latitude : ''),
      longitude:
          gps?.longitude.toString() ?? (keepLocation ? state.longitude : ''),
      locationLabel: keepLocation
          ? state.locationLabel
          : CreatePostState.photoLocationLabel,
    );
  }

  /// The link to a still map picture of the chosen location (or the region
  /// before one is chosen), sized [width] x [height]. Null without a Mapbox
  /// token.
  Uri? locationPreviewUrl({
    required int width,
    required int height,
    required bool isDarkMode,
  }) => ref
      .read(locationPreviewServiceProvider)
      .previewUrl(
        location: state.location,
        width: width,
        height: height,
        isDarkMode: isDarkMode,
      );

  void setLocation(PostLocation location) {
    if (state.isBusy || state.submittedId != null || !location.isValid) return;
    _request++;
    state = state.copyWith(
      latitude: location.latitude.toString(),
      longitude: location.longitude.toString(),
      locationLabel: location.label,
    );
  }

  /// Clears the chosen observation location so the user can choose another.
  void clearLocation() {
    if (state.isBusy || state.submittedId != null) return;
    _request++;
    state = state.copyWith(
      latitude: '',
      longitude: '',
      locationLabel: 'Pinned location',
    );
  }

  /// Removes the cover photo and its AI analysis. The first extra photo, if
  /// any, becomes the cover.
  void removePhoto() {
    if (state.isBusy) return;
    _request++;
    final extras = state.extraPhotoPaths;
    state = state.copyWith(
      clearPhoto: true,
      photoPath: extras.isEmpty ? null : extras.first,
      extraPhotoPaths: extras.isEmpty ? null : extras.sublist(1),
    );
  }

  /// Removes the extra photo at [index] (0 is the first photo after the
  /// cover).
  void removeExtraPhoto(int index) {
    final extras = state.extraPhotoPaths;
    if (state.isBusy || index < 0 || index >= extras.length) return;
    _request++;
    state = state.copyWith(extraPhotoPaths: [...extras]..removeAt(index));
  }

  /// Adds photos after the cover from the camera or the gallery, up to
  /// [PostDraft.maxPhotos] in all. Photos over 5 MB, and any beyond the
  /// limit, are left out with a note saying so.
  Future<void> addPhotos(PostPhotoSource source) async {
    if (state.isBusy || state.submittedId != null) return;
    final free = state.freePhotoSlots;
    if (free <= 0) {
      if (state.photoPath != null) {
        state = state.copyWith(photoNotice: _photoLimitNote);
      }
      return;
    }
    final request = ++_request;
    state = state.copyWith(isBusy: true);
    final picker = ref.read(postPhotoPickerServiceProvider);
    final kept = <String>[];
    var tooLarge = 0, overLimit = 0;
    try {
      final picked = switch (source) {
        PostPhotoSource.camera => [?await picker.takePhoto()],
        PostPhotoSource.gallery => await picker.pickPhotos(limit: free),
      };
      for (final path in picked) {
        if (kept.length == free) {
          overLimit++;
        } else if (await picker.isTooLarge(path)) {
          tooLarge++;
        } else {
          kept.add(path);
        }
      }
    } catch (_) {
      if (_disposed || request != _request) return;
      state = state.copyWith(
        isBusy: false,
        photoNotice: source == PostPhotoSource.camera
            ? 'Could not open the camera. Please try again.'
            : 'Could not open your photos. Please try again.',
      );
      return;
    }
    if (_disposed || request != _request) return;
    state = state.copyWith(
      isBusy: false,
      extraPhotoPaths: [...state.extraPhotoPaths, ...kept],
      photoNotice: _leftOutNote(tooLarge: tooLarge, overLimit: overLimit),
    );
  }

  static const _photoLimitNote =
      'A post can have up to ${PostDraft.maxPhotos} photos.';

  static String? _leftOutNote({required int tooLarge, required int overLimit}) {
    String photos(int count) =>
        count == 1 ? '1 photo was' : '$count photos were';
    final notes = [
      if (tooLarge > 0) '${photos(tooLarge)} over 5 MB and left out.',
      if (overLimit > 0) '$_photoLimitNote ${photos(overLimit)} left out.',
    ];
    return notes.isEmpty ? null : notes.join(' ');
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
            'Add a photo, choose a category and select an observation location on the map.',
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
      photoPaths: state.photoPaths,
      aiResult: state.aiResult,
    );
    state = state.copyWith(isBusy: true);
    try {
      final id = await ref.read(createPostServiceProvider).submit(draft);
      if (_disposed || request != _request) return false;
      state = state.copyWith(isBusy: false, submittedId: id);
      // Show the new pending post in My Gallery. A gallery that was never
      // opened loads it anyway when Profile is first shown.
      if (ref.exists(galleryViewModelProvider)) {
        unawaited(ref.read(galleryViewModelProvider.notifier).reload());
      }
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
