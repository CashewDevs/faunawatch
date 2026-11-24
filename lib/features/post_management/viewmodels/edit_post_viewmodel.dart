import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faunawatch/core/auth/current_user_provider.dart';
import 'package:faunawatch/features/create_post/models/post_photo_source.dart';
import 'package:faunawatch/features/create_post/services/post_photo_picker_service.dart';
import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'package:faunawatch/features/post_management/models/edit_post_state.dart';
import 'package:faunawatch/features/post_management/services/edit_post_service.dart';
import 'package:faunawatch/features/post_management/viewmodels/post_actions_viewmodel.dart';

export 'package:faunawatch/features/post_management/models/edit_post_state.dart';

/// The Edit post screen of one of the user's own posts ([arg] is its id).
///
/// - The caption can always change; that alone keeps the post's status.
/// - Photos (1 to 3) can be removed, added or made the cover. Any photo
///   change sends the post back for review.
/// - A new cover needs a FaunaLens analysis before saving, and its category
///   becomes the post's.
class EditPostViewModel
    extends AutoDisposeFamilyNotifier<EditPostState, String> {
  late EditPostService _service;
  int _generation = 0;
  bool _disposed = false;

  @override
  EditPostState build(String arg) {
    _service = ref.watch(editPostServiceProvider);
    // Another account must never see this post's form.
    ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    _disposed = false;
    ref.onDispose(() {
      _generation++;
      _disposed = true;
    });
    Future.microtask(() => _load(generation));
    return const EditPostState(isLoading: true);
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _load(int generation) async {
    try {
      final post = await _service.load(arg);
      if (!_isCurrent(generation)) return;
      state = post == null
          ? const EditPostState()
          : EditPostState(
              original: post,
              description: post.description,
              photos: post.photos,
            );
    } catch (_) {
      if (_isCurrent(generation)) {
        state = const EditPostState(hasError: true);
      }
    }
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    state = const EditPostState(isLoading: true);
    await _load(++_generation);
  }

  bool get _locked => state.isSaving || state.outcome != null;

  void editDescription(String value) {
    if (_locked) return;
    state = state.copyWith(description: value, clearError: true);
  }

  /// Removes the photo at [index]. Removing the cover makes the next photo
  /// the cover.
  void removePhoto(int index) {
    if (_locked || state.isBusy) return;
    final photos = [...state.photos];
    if (index < 0 || index >= photos.length) return;
    photos.removeAt(index);
    state = state.copyWith(
      photos: photos,
      clearError: true,
      clearPhotoNotice: true,
    );
  }

  /// Moves the photo at [index] to the front, as the cover.
  void makeCover(int index) {
    if (_locked || state.isBusy) return;
    final photos = [...state.photos];
    if (index <= 0 || index >= photos.length) return;
    photos.insert(0, photos.removeAt(index));
    state = state.copyWith(photos: photos, clearError: true);
  }

  /// Adds photos from the camera or the gallery, up to 3 in all. Photos over
  /// 5 MB, and any beyond the limit, are left out with a note saying so.
  Future<void> addPhotos(PostPhotoSource source) async {
    if (_locked || state.isBusy) return;
    final free = state.freePhotoSlots;
    if (free <= 0) {
      state = state.copyWith(photoNotice: _limitNote);
      return;
    }
    final generation = _generation;
    state = state.copyWith(isBusy: true, clearPhotoNotice: true);
    final picker = ref.read(postPhotoPickerServiceProvider);
    final kept = <NewPhoto>[];
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
          kept.add(NewPhoto(path));
        }
      }
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        isBusy: false,
        photoNotice: source == PostPhotoSource.camera
            ? 'Could not open the camera. Please try again.'
            : 'Could not open your photos. Please try again.',
      );
      return;
    }
    if (!_isCurrent(generation)) return;
    String photos(int count) =>
        count == 1 ? '1 photo was' : '$count photos were';
    final notes = [
      if (tooLarge > 0) '${photos(tooLarge)} over 5 MB and left out.',
      if (overLimit > 0) '$_limitNote ${photos(overLimit)} left out.',
    ];
    state = state.copyWith(
      isBusy: false,
      photos: [...state.photos, ...kept],
      photoNotice: notes.isEmpty ? null : notes.join(' '),
    );
  }

  static const _limitNote =
      'A post can have up to ${EditPostState.maxPhotos} photos.';

  /// A file path of the cover for the AI to read: a new photo's own file,
  /// or a copy of a photo the post already has. Null when that fails.
  Future<String?> coverForAnalysis() async {
    final cover = state.cover;
    if (cover == null || _locked || state.isBusy) return null;
    switch (cover) {
      case NewPhoto(:final path):
        return path;
      case ExistingPhoto():
        final generation = _generation;
        state = state.copyWith(isBusy: true, clearPhotoNotice: true);
        try {
          final path = await _service.localCopy(cover);
          if (!_isCurrent(generation)) return null;
          state = state.copyWith(isBusy: false);
          return path;
        } catch (_) {
          if (_isCurrent(generation)) {
            state = state.copyWith(
              isBusy: false,
              photoNotice:
                  'Could not get this photo ready for the AI. '
                  'Check your connection and try again.',
            );
          }
          return null;
        }
    }
  }

  /// The FaunaLens analysis of the cover the user chose to use. It counts
  /// only while that photo stays the cover.
  void useAnalysis(String coverKey, AiIdentification result) {
    if (_locked) return;
    state = state.copyWith(
      analysis: result,
      analysisFor: coverKey,
      clearError: true,
    );
  }

  void removeAnalysis() {
    if (_locked) return;
    state = state.copyWith(clearAnalysis: true);
  }

  /// Saves what changed. The caption goes first: if the photos then fail,
  /// the post still has its old photos and status.
  Future<void> save() async {
    final original = state.original;
    if (!state.canSave || original == null) return;
    final generation = _generation;
    state = state.copyWith(isSaving: true, clearError: true);
    final sentForReview = state.photosChanged;
    try {
      if (state.captionChanged) {
        await _service.updateCaption(arg, state.description.trim());
      }
      if (sentForReview) {
        await _service.replacePhotos(
          arg,
          state.photos,
          analysis: state.coverChanged ? state.coverAnalysis : null,
        );
      }
    } on EditPostException catch (error) {
      if (_isCurrent(generation)) {
        state = state.copyWith(isSaving: false, error: error.message);
      }
      return;
    } catch (_) {
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isSaving: false,
          error: EditPostException.failed.message,
        );
      }
      return;
    }
    ref
        .read(postActionsViewModelProvider.notifier)
        .postEdited(arg, sentForReview: sentForReview);
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      isSaving: false,
      outcome: sentForReview
          ? EditPostOutcome.sentForReview
          : EditPostOutcome.saved,
    );
  }
}

final editPostViewModelProvider = NotifierProvider.autoDispose
    .family<EditPostViewModel, EditPostState, String>(EditPostViewModel.new);
