import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';
import 'post_draft.dart';
import 'post_location.dart';

class CreatePostState {
  const CreatePostState({
    this.category,
    this.latitude = '',
    this.longitude = '',
    this.locationLabel = 'Pinned location',
    this.description = '',
    this.species = '',
    this.notes = '',
    this.photoPath,
    this.extraPhotoPaths = const [],
    this.photoNotice,
    this.aiResult,
    this.isBusy = false,
    this.error,
    this.submittedId,
  });

  /// The location label when the location came from the photo's GPS.
  static const photoLocationLabel = 'Photo location';

  final ReportCategory? category;
  final String latitude, longitude, description, species, notes;

  /// The cover photo: the one from FaunaLens, which the AI looked at.
  final String? photoPath, error, submittedId;

  /// Photos added on the form after the cover, in the order they were added.
  final List<String> extraPhotoPaths;

  /// Why some picked photos were left out; shown under the photos.
  final String? photoNotice;

  /// The FaunaLens analysis of [photoPath], if the user chose to use it.
  final AiIdentification? aiResult;
  final bool isBusy;
  final String locationLabel;

  /// Every photo in upload order, the cover first.
  List<String> get photoPaths => [?photoPath, ...extraPhotoPaths];

  /// How many more photos fit. Extras need a cover first.
  int get freePhotoSlots =>
      photoPath == null ? 0 : PostDraft.maxPhotos - photoPaths.length;

  PostLocation? get location => hasLocation
      ? PostLocation(
          latitude: double.parse(latitude),
          longitude: double.parse(longitude),
          label: locationLabel,
        )
      : null;

  bool get hasLocation {
    final lat = double.tryParse(latitude);
    final lng = double.tryParse(longitude);
    return lat != null && lng != null && PostDraft.validCoordinates(lat, lng);
  }

  /// Every post needs a photo, a category and a location.
  bool get canSubmit =>
      photoPath != null &&
      category != null &&
      hasLocation &&
      !isBusy &&
      submittedId == null;

  CreatePostState copyWith({
    ReportCategory? category,
    String? latitude,
    String? longitude,
    String? locationLabel,
    String? description,
    String? species,
    String? notes,
    String? photoPath,
    List<String>? extraPhotoPaths,
    String? photoNotice,
    bool clearPhoto = false,
    bool clearAiResult = false,
    bool? isBusy,
    String? error,
    String? submittedId,
  }) => CreatePostState(
    category: category ?? this.category,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    locationLabel: locationLabel ?? this.locationLabel,
    description: description ?? this.description,
    species: species ?? this.species,
    notes: notes ?? this.notes,
    photoPath: photoPath ?? (clearPhoto ? null : this.photoPath),
    extraPhotoPaths: extraPhotoPaths ?? this.extraPhotoPaths,
    photoNotice: photoNotice,
    // The analysis describes the cover photo, so it goes with it.
    aiResult: clearPhoto || clearAiResult ? null : aiResult,
    isBusy: isBusy ?? this.isBusy,
    error: error,
    submittedId: submittedId ?? this.submittedId,
  );
}
