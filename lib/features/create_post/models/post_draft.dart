import 'package:faunawatch/features/fauna_lens/models/ai_identification.dart';

enum ReportCategory {
  animalInNeed('animal_in_need', 'Animal in need'),
  potentiallyDangerousAnimal(
    'potentially_dangerous_animal',
    'Potentially dangerous animal',
  ),
  possibleInvasiveSpecies(
    'possible_invasive_species',
    'Possible invasive species',
  ),
  otherWildlifeIncident('other_wildlife_incident', 'Other wildlife incident');

  const ReportCategory(this.value, this.label);
  final String value;
  final String label;
}

/// User-entered report data. Coordinates are mandatory at the persistence boundary.
class PostDraft {
  const PostDraft({
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.species = '',
    this.notes = '',
    this.photoPaths = const [],
    this.aiResult,
  });

  /// The most photos one post can have. The database refuses more.
  static const maxPhotos = 3;

  final ReportCategory category;
  final double latitude, longitude;
  final String description, species, notes;

  /// The post's photos in order. The first is the cover: it is uploaded
  /// first, so the feed, the map pin and the admin site show it first.
  final List<String> photoPaths;

  /// The cover photo, if there is one.
  String? get photoPath => photoPaths.isEmpty ? null : photoPaths.first;

  /// The FaunaLens analysis of the cover photo, saved to `ai_analyses` with
  /// the report. Only kept with the photo it describes.
  final AiIdentification? aiResult;

  /// The analysis to save, if any. Ignored without its photo.
  AiIdentification? get analysis => photoPath == null ? null : aiResult;

  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  Map<String, dynamic> toRow(String userId) {
    if (!validCoordinates(latitude, longitude)) {
      throw ArgumentError('A valid report location is required.');
    }
    if (photoPaths.length > maxPhotos) {
      throw ArgumentError('A post can have up to $maxPhotos photos.');
    }
    String? optional(String value) =>
        value.trim().isEmpty ? null : value.trim();
    return {
      'user_id': userId,
      'category': category.value,
      'latitude': latitude,
      'longitude': longitude,
      'description': optional(description),
      'user_species': optional(species),
      'user_notes': optional(notes),
      'status': 'pending',
      // The analysis row is inserted in the same submission; if that fails
      // the report is removed, so 'completed' never lacks its row.
      'ai_status': analysis == null ? 'unavailable' : 'completed',
    };
  }
}
