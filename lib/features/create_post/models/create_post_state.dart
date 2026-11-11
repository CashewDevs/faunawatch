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
    this.aiResult,
    this.isBusy = false,
    this.error,
    this.submittedId,
  });

  final ReportCategory? category;
  final String latitude, longitude, description, species, notes;
  final String? photoPath, error, submittedId;

  /// The FaunaLens analysis of [photoPath], if the user chose to use it.
  final AiIdentification? aiResult;
  final bool isBusy;
  final String locationLabel;

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

  bool get canSubmit =>
      category != null && hasLocation && !isBusy && submittedId == null;

  CreatePostState copyWith({
    ReportCategory? category,
    String? latitude,
    String? longitude,
    String? locationLabel,
    String? description,
    String? species,
    String? notes,
    String? photoPath,
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
    photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
    // The analysis describes one photo, so it goes with it.
    aiResult: clearPhoto || clearAiResult ? null : aiResult,
    isBusy: isBusy ?? this.isBusy,
    error: error,
    submittedId: submittedId ?? this.submittedId,
  );
}
